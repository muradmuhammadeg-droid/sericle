(function(){
  // List of SQL files to fetch and display
  const files = [
    { name: '001_create_profiles_table.sql', raw: 'https://raw.githubusercontent.com/muradmuhammadeg-droid/sericle/main/sql/001_create_profiles_table.sql' },
    { name: '002_save_profile_function.sql', raw: 'https://raw.githubusercontent.com/muradmuhammadeg-droid/sericle/main/sql/002_save_profile_function.sql' },
    { name: '003_social_schema.sql', raw: 'https://raw.githubusercontent.com/muradmuhammadeg-droid/sericle/main/sql/003_social_schema.sql' },
    { name: '004_social_functions.sql', raw: 'https://raw.githubusercontent.com/muradmuhammadeg-droid/sericle/main/sql/004_social_functions.sql' },
    { name: '005_notifications.sql', raw: 'https://raw.githubusercontent.com/muradmuhammadeg-droid/sericle/main/sql/005_notifications.sql' },
    { name: '006_bookmarks.sql', raw: 'https://raw.githubusercontent.com/muradmuhammadeg-droid/sericle/main/sql/006_bookmarks.sql' },
    { name: '007_moderation.sql', raw: 'https://raw.githubusercontent.com/muradmuhammadeg-droid/sericle/main/sql/007_moderation.sql' }
  ];

  function escapeHtml(s){
    return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  }

  async function fetchFile(url){
    try{
      const res = await fetch(url);
      if(!res.ok) throw new Error('HTTP '+res.status);
      return await res.text();
    }catch(e){
      return null;
    }
  }

  function makeDetails(name, rawUrl, content){
    const d = document.createElement('details');
    const s = document.createElement('summary');
    s.textContent = name;
    const links = document.createElement('div');
    links.style.fontSize = '13px';
    links.style.margin = '6px 0';
    const raw = document.createElement('a'); raw.href = rawUrl; raw.target = '_blank'; raw.rel = 'noopener'; raw.textContent = 'Open raw'; raw.style.marginRight = '12px';
    links.appendChild(raw);

    const pre = document.createElement('pre');
    pre.textContent = content || 'Failed to load file.';

    d.appendChild(s);
    d.appendChild(links);
    d.appendChild(pre);
    return d;
  }

  document.addEventListener('DOMContentLoaded', async function(){
    const container = document.getElementById('files');
    if(!container) return;

    for(const f of files){
      const placeholder = document.createElement('details');
      const summary = document.createElement('summary');
      summary.textContent = f.name + ' — loading...';
      const p = document.createElement('p'); p.className = 'loading'; p.textContent = 'Fetching...';
      placeholder.appendChild(summary);
      placeholder.appendChild(p);
      container.appendChild(placeholder);

      const txt = await fetchFile(f.raw);
      container.removeChild(placeholder);

      const details = makeDetails(f.name, f.raw, txt || 'Unable to load file. Try opening the raw link.');
      container.appendChild(details);
    }
  });
})();
