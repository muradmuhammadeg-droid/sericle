const express = require('express');
const path = require('path');
const session = require('express-session');
const passport = require('passport');
const GitHubStrategy = require('passport-github2').Strategy;
const sqlite3 = require('sqlite3');
const sqlite = require('sqlite');
const bodyParser = require('body-parser');

(async function(){
  const db = await sqlite.open({ filename: 'memory.db', driver: sqlite3.Database });
  await db.exec(`CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, github_id TEXT UNIQUE, username TEXT, displayName TEXT, avatar TEXT, createdAt TEXT);
  CREATE TABLE IF NOT EXISTS posts (id INTEGER PRIMARY KEY, author_id INTEGER, author_name TEXT, content TEXT, createdAt TEXT);
  CREATE TABLE IF NOT EXISTS likes (id INTEGER PRIMARY KEY, user_id INTEGER, post_id INTEGER, createdAt TEXT, UNIQUE(user_id, post_id));
  CREATE TABLE IF NOT EXISTS comments (id INTEGER PRIMARY KEY, post_id INTEGER, user_id INTEGER, content TEXT, createdAt TEXT);`);

  passport.serializeUser((user, done) => done(null, user.id));
  passport.deserializeUser(async (id, done) => {
    try { const user = await db.get('SELECT id, username, displayName, avatar FROM users WHERE id = ?', [id]); done(null, user); } catch (e) { done(e); }
  });

  passport.use(new GitHubStrategy({
    clientID: process.env.GITHUB_CLIENT_ID || '',
    clientSecret: process.env.GITHUB_CLIENT_SECRET || '',
    callbackURL: process.env.GITHUB_CALLBACK_URL || 'http://localhost:3000/auth/github/callback'
  }, async (accessToken, refreshToken, profile, done) => {
    try {
      let user = await db.get('SELECT * FROM users WHERE github_id = ?', [profile.id]);
      if (!user) {
        const now = new Date().toISOString();
        const result = await db.run('INSERT INTO users (github_id, username, displayName, avatar, createdAt) VALUES (?,?,?,?,?)', [profile.id, profile.username || null, profile.displayName || profile.username || null, profile._json && profile._json.avatar_url || null, now]);
        user = await db.get('SELECT * FROM users WHERE id = ?', [result.lastID]);
      }
      return done(null, user);
    } catch (err) { return done(err); }
  }));

  const app = express();
  app.use(bodyParser.json());
  app.use(session({ secret: process.env.SESSION_SECRET || 'change_me', resave: false, saveUninitialized: false }));
  app.use(passport.initialize());
  app.use(passport.session());

  const requireAuth = (req, res, next) => { if (!req.isAuthenticated || !req.isAuthenticated()) return res.status(401).json({ error: 'Unauthorized' }); return next(); };

  app.use(express.static(path.join(__dirname, 'public')));

  app.get('/auth/github', passport.authenticate('github', { scope: [ 'user:email' ] }));

  app.get('/auth/github/callback', passport.authenticate('github', { failureRedirect: '/' }), (req, res) => {
    res.redirect('/');
  });

  app.post('/auth/logout', (req, res) => {
    req.logout(() => {});
    req.session.destroy(() => res.json({ ok: true }));
  });

  app.get('/api/me', (req, res) => {
    if (!req.user) return res.json({ user: null });
    return res.json({ user: req.user });
  });

  app.get('/api/posts', async (req, res) => {
    const rows = await db.all('SELECT posts.id, posts.author_id, posts.author_name, posts.content, posts.createdAt FROM posts ORDER BY posts.id DESC');
    const posts = [];
    for (const p of rows) {
      const likesCountRow = await db.get('SELECT COUNT(*) AS c FROM likes WHERE post_id = ?', [p.id]);
      const commentsRows = await db.all('SELECT comments.id, comments.content, comments.createdAt, users.username, users.displayName, users.avatar FROM comments LEFT JOIN users ON comments.user_id = users.id WHERE comments.post_id = ? ORDER BY comments.id ASC', [p.id]);
      let liked = false;
      if (req.user) {
        const l = await db.get('SELECT 1 FROM likes WHERE post_id = ? AND user_id = ? LIMIT 1', [p.id, req.user.id]);
        liked = !!l;
      }
      posts.push({ id: p.id, author_id: p.author_id, author_name: p.author_name, content: p.content, createdAt: p.createdAt, likes: likesCountRow.c || 0, liked, comments: commentsRows });
    }
    res.json(posts);
  });

  app.post('/api/posts', async (req, res) => {
    if (!req.isAuthenticated || !req.isAuthenticated()) return res.status(401).json({ error: 'Unauthorized' });
    const content = (req.body.content || '').toString().trim();
    if (!content) return res.status(400).json({ error: 'Content required' });
    const now = new Date().toISOString();
    const author_name = req.user.displayName || req.user.username || 'Anonymous';
    const result = await db.run('INSERT INTO posts (author_id, author_name, content, createdAt) VALUES (?,?,?,?)', [req.user.id, author_name, content, now]);
    const post = await db.get('SELECT id, author_id, author_name, content, createdAt FROM posts WHERE id = ?', [result.lastID]);
    res.status(201).json(post);
  });

  app.post('/api/posts/:id/like', async (req, res) => {
    if (!req.isAuthenticated || !req.isAuthenticated()) return res.status(401).json({ error: 'Unauthorized' });
    const postId = Number(req.params.id);
    const userId = req.user.id;
    const exists = await db.get('SELECT id FROM likes WHERE post_id = ? AND user_id = ?', [postId, userId]);
    if (exists) {
      await db.run('DELETE FROM likes WHERE id = ?', [exists.id]);
    } else {
      await db.run('INSERT INTO likes (user_id, post_id, createdAt) VALUES (?,?,?)', [userId, postId, new Date().toISOString()]);
    }
    const likesCountRow = await db.get('SELECT COUNT(*) AS c FROM likes WHERE post_id = ?', [postId]);
    const liked = !exists;
    res.json({ likes: likesCountRow.c || 0, liked });
  });

  app.post('/api/posts/:id/comments', async (req, res) => {
    if (!req.isAuthenticated || !req.isAuthenticated()) return res.status(401).json({ error: 'Unauthorized' });
    const postId = Number(req.params.id);
    const content = (req.body.content || '').toString().trim();
    if (!content) return res.status(400).json({ error: 'Content required' });
    const now = new Date().toISOString();
    const result = await db.run('INSERT INTO comments (post_id, user_id, content, createdAt) VALUES (?,?,?,?)', [postId, req.user.id, content, now]);
    const comment = await db.get('SELECT comments.id, comments.content, comments.createdAt, users.username, users.displayName, users.avatar FROM comments LEFT JOIN users ON comments.user_id = users.id WHERE comments.id = ?', [result.lastID]);
    res.status(201).json(comment);
  });

  app.get('/api/posts/:id/comments', async (req, res) => {
    const postId = Number(req.params.id);
    const comments = await db.all('SELECT comments.id, comments.content, comments.createdAt, users.username, users.displayName, users.avatar FROM comments LEFT JOIN users ON comments.user_id = users.id WHERE comments.post_id = ? ORDER BY comments.id ASC', [postId]);
    res.json(comments);
  });

  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log(`Sericle server listening on port ${PORT}`));
})();
