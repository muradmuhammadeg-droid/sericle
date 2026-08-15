const $ = q => document.querySelector(q);
const feed = $('#feed');
const author = $('#author');
const content = $('#content');
const postBtn = $('#postBtn');

async function loadPosts(){
  const res = await fetch('/api/posts');
  const posts = await res.json();
  renderPosts(posts);
}

function renderPosts(posts){
  feed.innerHTML = '';
  posts.forEach(p => {
    const el = document.createElement('article');
    el.className = 'post';
    const meta = document.createElement('div');
    meta.className = 'meta';
    meta.textContent = `${p.author} • ${new Date(p.createdAt).toLocaleString()}`;
    const body = document.createElement('div');
    body.className = 'content';
    body.textContent = p.content;
    el.appendChild(meta);
    el.appendChild(body);
    feed.appendChild(el);
  });
}

postBtn.addEventListener('click', async () => {
  const a = author.value;
  const c = content.value;
  if (!c.trim()) return;
  postBtn.disabled = true;
  try {
    const res = await fetch('/api/posts', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({author: a, content: c})
    });
    if (res.ok) {
      content.value = '';
      await loadPosts();
    } else {
      const err = await res.json();
      alert(err.error || 'Failed to post');
    }
  } catch (e) {
    alert('Network error');
  } finally {
    postBtn.disabled = false;
  }
});

window.addEventListener('load', loadPosts);
