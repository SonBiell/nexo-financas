document.querySelectorAll('form[method="post"], form[method="POST"]').forEach((form) => {
  if (form.querySelector('input[name="csrf_token"]')) return;
  const input = document.createElement('input');
  input.type = 'hidden'; input.name = 'csrf_token';
  input.value = document.querySelector('meta[name="csrf-token"]')?.content || '';
  form.prepend(input);
});
document.querySelectorAll('form[data-confirm]').forEach((form) => {
  form.addEventListener('submit', (event) => {
    if (!window.confirm(form.dataset.confirm)) event.preventDefault();
  });
});
document.querySelectorAll('.auto-submit').forEach((field) => {
  field.addEventListener('change', () => field.form?.submit());
});

const categoryDialog = document.querySelector('#category-editor');
document.querySelectorAll('.edit-category').forEach((button) => {
  button.addEventListener('click', () => {
    document.querySelector('#category-edit-form').action = `/categories/${button.dataset.id}/edit`;
    document.querySelector('#edit-category-name').value = button.dataset.name;
    document.querySelector('#edit-category-color').value = button.dataset.color;
    categoryDialog.showModal();
  });
});
document.querySelectorAll('.dialog-close, .dialog-cancel').forEach((button) => {
  button.addEventListener('click', () => categoryDialog?.close());
});

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => navigator.serviceWorker.register('/static/service-worker.js'));
}
let installPrompt;
const installButton = document.querySelector('.install-app');
window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  installPrompt = event;
  if (installButton) installButton.hidden = false;
});
installButton?.addEventListener('click', async () => {
  if (!installPrompt) return;
  await installPrompt.prompt();
  installPrompt = null;
  installButton.hidden = true;
});

