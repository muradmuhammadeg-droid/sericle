const $ = q => document.querySelector(q);
const feed = $('#feed');
const author = $('#author');
const content = $('#content');
const postBtn = $('#postBtn');
const loginBtn = $('#loginBtn');
const logoutBtn = $('#logoutBtn');
let currentUser = null;

async function api(path, opts = {}){
  opts.credentials = 'include';
  opts.headers = opts.headers || {};
  if (opts.body && typeof opts.body === 'object') opts.headers['Content-Type'] = 'application/json';
  if (opts.body && opts.headers['Content-Type'] === 'application/json') opts.body = JSON.stringify(opts.body);
  const res = await fetch(path, opts);
  const data = await res.json().catch(() => null);
  if (!res.ok) throw data || new Error('Request failed');
  return data;
}

async function loadUser(){
  try{
    const r = await api('/api/me');
    currentUser = r.user;
    if (currentUser){
      author.value = currentUser.displayName || currentUser.username || 'You';
      loginBtn.style.display = 'none';
      logoutBtn.style.display = 'inline-block';
    } else {
      author.value = '';
      loginBtn.style.display = 'inline-block';
      logoutBtn.style.display = 'none';
    }
  }catch(e){
    currentUser = null;
  }
}

async function loadPosts(){
  const posts = await api('/api/posts');
  renderPosts(posts);
}

function renderPosts(posts){
  feed.innerHTML = '';
  posts.forEach(p => {
    const el = document.createElement('article');
    el.className = 'post';
    const meta = document.createElement('div');
    meta.className = 'meta';
    const left = document.createElement('div');
    left.textContent = `${p.author_name} • ${new Date(p.createdAt).toLocaleString()}`;
    const right = document.createElement('div');
    const likeBtn = document.createElement('button');
    likeBtn.textContent = `❤ ${p.likes}`;
    likeBtn.disabled = !currentUser;
    likeBtn.addEventListener('click', async () => {
      try{
        const res = await api(`/api/posts/${p.id}/like`, { method: 'POST' });
        likeBtn.textContent = `❤ ${res.likes}`;
      }catch(e){alert(e.error || 'Failed');}
    });
    right.appendChild(likeBtn);
    meta.appendChild(left);
    meta.appendChild(right);
    const body = document.createElement('div');
    body.className = 'content';
    body.textContent = p.content;
    el.appendChild(meta);
    el.appendChild(body);

    const actions = document.createElement('div');
    actions.className = 'actions';
    const commentInput = document.createElement('input');
    commentInput.placeholder = 'Write a comment';
    commentInput.style.flex = '1';
    const commentBtn = document.createElement('button');
    commentBtn.textContent = 'Comment';
    commentBtn.disabled = !currentUser;
    commentBtn.addEventListener('click', async () => {
      const text = commentInput.value.trim();
      if (!text) return;
      try{
        await api(`/api/posts/${p.id}/comments`, { method: 'POST', body: { content: text } });
        commentInput.value = '';
        await loadPosts();
      }catch(e){alert(e.error || 'Failed');}
    });
    actions.appendChild(commentInput);
    actions.appendChild(commentBtn);
    el.appendChild(actions);

    const commentsDiv = document.createElement('div');
    commentsDiv.className = 'comments';
    p.comments.forEach(c => {
      const ce = document.createElement('div');
      ce.className = 'comment';
      const cmMeta = document.createElement('div');
      cmMeta.className = 'meta';
      cmMeta.textContent = `${c.displayName || c.username || 'User'} • ${new Date(c.createdAt).toLocaleString()}`;
      const cmBody = document.createElement('div');
      cmBody.textContent = c.content;
      ce.appendChild(cmMeta);
      ce.appendChild(cmBody);
      commentsDiv.appendChild(ce);
    });
    el.appendChild(commentsDiv);

    feed.appendChild(el);
  });
}

postBtn.addEventListener('click', async () => {
  const c = content.value.trim();
  if (!c) return;
  postBtn.disabled = true;
  try{
    await api('/api/posts', { method: 'POST', body: { content: c } });
    content.value = '';
    await loadPosts();
  }catch(e){
    alert(e.error || 'Failed to post');
  }finally{ postBtn.disabled = false; }
});

loginBtn.addEventListener('click', () => { window.location.href = '/auth/github'; });
logoutBtn.addEventListener('click', async () => { try{ await api('/auth/logout', { method: 'POST' }); await loadUser(); await loadPosts(); }catch(e){} });

window.addEventListener('load', async () => { await loadUser(); await loadPosts(); });
