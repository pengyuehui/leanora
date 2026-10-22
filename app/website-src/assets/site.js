// Keep links to the former Go-only homepage meaningful after introducing the hub.
if (location.pathname === '/' && ['#review', '#training', '#parents'].includes(location.hash)) {
  location.replace('/go/' + location.hash);
}

const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const revealTargets = document.querySelectorAll('[data-reveal]');
if (!reduceMotion.matches && 'IntersectionObserver' in window) {
  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        entry.target.classList.add('revealed');
        observer.unobserve(entry.target);
      }
    }
  }, { threshold: 0.08 });
  for (const target of revealTargets) {
    target.classList.add('will-reveal');
    observer.observe(target);
  }
}

const mobileNav = document.querySelector('.mobile-nav');
mobileNav?.addEventListener('click', event => {
  if (event.target.closest('a')) mobileNav.open = false;
});
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && mobileNav?.open) {
    mobileNav.open = false;
    mobileNav.querySelector('summary').focus();
  }
});

const imageDialog = document.querySelector('.image-dialog');
const dialogImage = document.querySelector('#dialog-image');
const imageCaption = document.querySelector('#image-caption');
let imageOpener;
for (const trigger of document.querySelectorAll('[data-image]')) {
  trigger.addEventListener('click', () => {
    imageOpener = trigger;
    dialogImage.src = trigger.dataset.image;
    dialogImage.alt = trigger.dataset.caption;
    imageCaption.textContent = trigger.dataset.caption;
    imageDialog.showModal();
    document.documentElement.classList.add('dialog-open');
  });
}
document.querySelector('[data-close-dialog]')?.addEventListener('click', () => imageDialog.close());
imageDialog?.addEventListener('click', event => {
  if (event.target === imageDialog) imageDialog.close();
});
imageDialog?.addEventListener('close', () => {
  document.documentElement.classList.remove('dialog-open');
  imageOpener?.focus();
  dialogImage.removeAttribute('src');
});
