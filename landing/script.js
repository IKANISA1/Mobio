/* ============================================================
   Mobio Landing Page — Interactions & Animations
   Zero dependencies. Respects prefers-reduced-motion.
   ============================================================ */

(function () {
  'use strict';

  // --- Scroll-triggered reveal animations ---
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  if (!prefersReducedMotion) {
    const revealElements = document.querySelectorAll('.reveal');
    const revealObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('visible');
            revealObserver.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.15, rootMargin: '0px 0px -40px 0px' }
    );

    revealElements.forEach((el, i) => {
      el.style.transitionDelay = `${i % 3 * 100}ms`;
      revealObserver.observe(el);
    });
  } else {
    // If reduced motion, make everything visible immediately
    document.querySelectorAll('.reveal').forEach((el) => {
      el.classList.add('visible');
    });
  }

  // --- Sticky nav background on scroll ---
  const nav = document.getElementById('nav');
  let lastScroll = 0;

  function handleNavScroll() {
    const scrollY = window.scrollY;
    if (scrollY > 60) {
      nav.classList.add('scrolled');
    } else {
      nav.classList.remove('scrolled');
    }
    lastScroll = scrollY;
  }

  window.addEventListener('scroll', handleNavScroll, { passive: true });
  handleNavScroll(); // Run on load

  // --- Mobile menu toggle ---
  const toggle = document.getElementById('nav-toggle');
  const links = document.getElementById('nav-links');

  toggle.addEventListener('click', () => {
    toggle.classList.toggle('active');
    links.classList.toggle('open');
    document.body.style.overflow = links.classList.contains('open') ? 'hidden' : '';
  });

  // Close menu on link click
  window.closeMenu = function () {
    toggle.classList.remove('active');
    links.classList.remove('open');
    document.body.style.overflow = '';
  };

  // --- Smooth scroll for anchor links ---
  document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener('click', function (e) {
      const targetId = this.getAttribute('href');
      if (targetId === '#') return;

      const targetEl = document.querySelector(targetId);
      if (!targetEl) return;

      e.preventDefault();
      const navHeight = nav.offsetHeight;
      const targetPos = targetEl.getBoundingClientRect().top + window.scrollY - navHeight - 20;

      window.scrollTo({
        top: targetPos,
        behavior: prefersReducedMotion ? 'auto' : 'smooth',
      });
    });
  });

  // --- Staggered card animation reset ---
  // Add stagger delays to grid children
  document.querySelectorAll('.features-grid .reveal, .steps-grid .reveal').forEach((el, i) => {
    el.style.transitionDelay = `${i * 120}ms`;
  });

})();
