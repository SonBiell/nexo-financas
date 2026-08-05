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

