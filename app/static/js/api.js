async function api(url, options = {}) {
    try { const res = await fetch(url, options); return await res.json(); }
    catch (e) { console.error(e); return { error: true }; }
}

async function uploadPhoto(file) {
    if (!file) return { ok: false };
    const fd = new FormData(); fd.append('photo', file); fd.append('admin_telegram_id', user?.id || 0);
    try { const res = await fetch('/api/admin/upload-photo', { method: 'POST', body: fd }); return await res.json(); }
    catch { return { ok: false }; }
}
