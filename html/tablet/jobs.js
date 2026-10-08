/**
 * Vanguard Jobs - "Jobs" tile for ph-tablet.
 * ph-tablet loads this module from its app registry; on open it shows a short splash, asks our
 * resource to open the Job Portal and closes the tablet.
 */
(function () {
  'use strict';

  var APP_ID = 'vanguard-jobs';
  var RESOURCE = 'vanguard-jobs';
  if (!window.phTablet) return;

  function openPortal() {
    return fetch('https://' + RESOURCE + '/openPortal', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: '{}',
    }).catch(function () {});
  }

  function mount(slot, ctx) {
    slot.style.cssText =
      'width:100%;height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;' +
      'gap:14px;background:#0f1114;color:#eef0ec;font-family:inherit;';
    var title = document.createElement('div');
    title.style.cssText = 'font-size:20px;font-weight:700';
    title.textContent = 'Opening Job Portal...';
    var sub = document.createElement('div');
    sub.style.cssText = 'font-size:13px;color:#98a09b';
    sub.textContent = 'Teams - Delivery - Recycling';
    slot.replaceChildren(title, sub);
    openPortal().then(function () { ctx.close(); });
  }

  function unmount(slot) {
    if (slot) slot.replaceChildren();
  }

  window.phTablet.registerApp(APP_ID, { mount: mount, unmount: unmount });
})();
