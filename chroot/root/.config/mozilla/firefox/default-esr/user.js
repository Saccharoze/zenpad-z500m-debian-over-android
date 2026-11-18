// Speed tuning for software rendering on the ZenPad chroot
// Video: skip AV1 (heaviest to decode without GPU) -> YouTube sends VP9/H.264
user_pref("media.av1.enabled", false);
// Block autoplay of audio+video (click to play)
user_pref("media.autoplay.default", 5);
// Fewer processes: no per-site isolation, max 2 content processes
user_pref("fission.autostart", false);
user_pref("dom.ipc.processCount", 2);
// Draw at most 30 fps (halves software painting work)
user_pref("layout.frame_rate", 30);
// No smooth scrolling / animations
user_pref("general.smoothScroll", false);
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("ui.prefersReducedMotion", 1);
// Unload background tabs when memory is low
user_pref("browser.tabs.unloadOnLowMemory", true);
// Lighter new-tab page
user_pref("browser.newtabpage.activity-stream.showWeather", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
// Save session less often (less disk work)
user_pref("browser.sessionstore.interval", 60000);

// --- extra trims: no Pocket, telemetry, studies, recommendations, auto-update (apt updates Firefox ESR)
user_pref("extensions.pocket.enabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("app.normandy.enabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);
user_pref("extensions.getAddons.showPane", false);
user_pref("app.update.auto", false);
user_pref("browser.newtabpage.activity-stream.feeds.snippets", false);
// smaller content on the 800x600 screen (1.0 = normal, lower = more fits)
user_pref("layout.css.devPixelsPerPx", "0.85");
// YouTube: get H.264 instead of VP9 (much lighter to decode in software; AV1 is already off).
user_pref("media.mediasource.vp9.enabled", false);
