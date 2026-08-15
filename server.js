const express = require('express');
const path = require('path');
const cors = require('cors');
const bodyParser = require('body-parser');

const app = express();
app.use(cors());
app.use(bodyParser.json());
const PORT = process.env.PORT || 3000;
const posts = [];

app.use(express.static(path.join(__dirname, 'public')));

app.get('/api/posts', (req, res) => {
  res.json(posts.slice().reverse());
});

app.post('/api/posts', (req, res) => {
  const { author, content } = req.body;
  if (!content || typeof content !== 'string' || content.trim() === '') {
    return res.status(400).json({ error: 'Content required' });
  }
  const post = {
    id: Date.now().toString(36) + Math.random().toString(36).slice(2,8),
    author: (author && author.trim()) || 'Anonymous',
    content: content.trim(),
    createdAt: new Date().toISOString()
  };
  posts.push(post);
  res.status(201).json(post);
});

app.listen(PORT, () => {
  console.log(`Sericle server listening on port ${PORT}`);
});
