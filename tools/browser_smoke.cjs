
/* Browser smoke helper. Requires an installed Playwright and Chromium.
   Set PLAYWRIGHT_MODULE and BROWSER_BIN when they are outside node_modules.
   node tools/browser_smoke.cjs <url> <output-directory> [boot|play|mobile]
   Screenshots are evidence; game-rule assertions live in the Godot suites. */
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const [url = 'http://127.0.0.1:8086', output = 'docs/screenshots/browser', scenario = 'boot'] = process.argv.slice(2);
(async () => {
 fs.mkdirSync(output, {recursive: true});
 const mobile = scenario === 'mobile';
 const viewport = mobile ? {width:844,height:390} : {width:1280,height:720};
 const browser = await chromium.launch({headless:true, ignoreDefaultArgs:['--mute-audio'], args:['--autoplay-policy=user-gesture-required'], ...(process.env.BROWSER_BIN ? {executablePath:process.env.BROWSER_BIN} : {})});
 const context = await browser.newContext({viewport, hasTouch:mobile, isMobile:mobile});
 if (process.env.PROBE_AUDIO) await context.addInitScript(()=>{
  window.__audioProbe={analysers:[]};
  const connect=AudioNode.prototype.connect;
  AudioNode.prototype.connect=function(destination,...args){
   if (destination instanceof AudioDestinationNode && !this.__cluckProbed) {
    this.__cluckProbed=true;
    const analyser=this.context.createAnalyser();
    analyser.fftSize=2048;
    window.__audioProbe.analysers.push(analyser);
    connect.call(this,analyser);
    return connect.call(analyser,destination,...args);
   }
   return connect.call(this,destination,...args);
  };
 });
 if (process.env.PROFILE_BROWSER) await context.addInitScript(()=>{
  const original=WebGL2RenderingContext.prototype.getParameter;
  window.__glQueries={};
  WebGL2RenderingContext.prototype.getParameter=function(parameter){
   const begin=performance.now();
   const result=original.call(this,parameter);
   const row=window.__glQueries[parameter] ||= {count:0,ms:0};
   row.count++;row.ms+=performance.now()-begin;
   return result;
  };
 });
 const page = await context.newPage();
 const errors = [];
 const logs = [];
 page.on('console', msg => { logs.push(msg.type()+': '+msg.text()); if(msg.type()==='error') errors.push(msg.text()); });
 page.on('pageerror', error => errors.push(error.message));
 const snap = async name => page.screenshot({path:path.join(output,name+'.png')});
 const click = async (x,y) => {
   const scale = Math.min(viewport.width/1280, viewport.height/720);
   const px = (viewport.width-1280*scale)/2+x*scale;
   const py = (viewport.height-720*scale)/2+y*scale;
   if(mobile) await page.touchscreen.tap(px,py); else await page.mouse.click(px,py);
 };
 try {
  const startupBegin = Date.now();
  await page.goto(url,{waitUntil:'domcontentloaded',timeout:60000});
  await page.waitForTimeout(250); await snap('00-web-loader');
  const loadingControlsHidden = await page.evaluate(()=>!document.getElementById('status') || document.getElementById('fullscreen')?.hidden === true);
  if (!loadingControlsHidden) errors.push('Fullscreen control overlaps the startup loader');
  await page.waitForFunction(()=>!document.getElementById('status'),{},{timeout:240000});
  logs.push('Startup time: '+(Date.now()-startupBegin)+' ms');
  await page.waitForTimeout(4500);
  await snap('01-ready');
  if (scenario!=='boot') {
   if (scenario === 'live') {
    await click(640,367); await page.keyboard.type('Arcade QA'); await click(640,456);
    await page.waitForTimeout(1500); await click(1035,620); await page.waitForTimeout(1000);
   }
   // First play goes straight to the menu; controls are taught on the field.
   await snap('03-menu');
   await click(1090,210); await page.waitForTimeout(1000); await snap('04-selection');
   const audioState = await page.evaluate(()=>window.CluckAudio?.status?.());
   logs.push('Web Audio: '+JSON.stringify(audioState));
   if (!audioState?.unlocked || !audioState.contexts?.includes('running')) errors.push('Web Audio did not unlock after user input');
   if (process.env.PROBE_AUDIO) {
    const audioSignal = await page.evaluate(async()=>{
     const analysers=window.__audioProbe?.analysers || [];
     let peak=0;
     for(let sample=0;sample<30;sample++){
      for(const analyser of analysers){
       const data=new Float32Array(analyser.fftSize);
       analyser.getFloatTimeDomainData(data);
       for(const value of data) peak=Math.max(peak,Math.abs(value));
      }
      await new Promise(resolve=>setTimeout(resolve,50));
     }
     return {analysers:analysers.length,peak};
    });
    logs.push('Web Audio signal: '+JSON.stringify(audioSignal));
    if (!audioSignal.analysers || audioSignal.peak < 0.0001) errors.push('No audible Web Audio samples reached the destination');
   }
   await click(300,335); await page.waitForTimeout(5000); await snap('05-gameplay');
   for (const [x,y] of [[340,600],[450,600],[640,400],[620,600],[780,600],[930,580]]) {
    await click(x,y); await page.waitForTimeout(330);
   }
   await click(1160,675); await click(80,675);
   await click(1190,45); await page.waitForTimeout(600); await snap('06-paused');
   await click(640,320); await page.waitForTimeout(700); await snap('07-resumed');
   const cdp = await context.newCDPSession(page);
   await cdp.send('Performance.enable');
   const beforeMetrics = await cdp.send('Performance.getMetrics');
   if (process.env.PROFILE_BROWSER) await page.evaluate(()=>{window.__glQueries={};});
   if (process.env.PROFILE_BROWSER) {
    await cdp.send('Profiler.enable'); await cdp.send('Profiler.start');
   }
   const timings = await page.evaluate(()=>new Promise(resolve=>{
    const frames=[];let previous=performance.now();
    function frame(now){frames.push(now-previous);previous=now;if(frames.length>=120)resolve(frames);else requestAnimationFrame(frame);}
    requestAnimationFrame(frame);
   }));
   const afterMetrics = await cdp.send('Performance.getMetrics');
   for (const name of ['TaskDuration','ScriptDuration','LayoutDuration']) {
    const start = beforeMetrics.metrics.find(m=>m.name===name)?.value || 0;
    const end = afterMetrics.metrics.find(m=>m.name===name)?.value || 0;
    logs.push(name+' over sample: '+(end-start).toFixed(3)+' seconds');
   }
   logs.push('GPU: '+await page.evaluate(()=>{
    const gl=document.getElementById('canvas').getContext('webgl2');
    const ext=gl?.getExtension('WEBGL_debug_renderer_info');
    return ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : 'unavailable';
   }));
   if (process.env.PROFILE_BROWSER) {
    const {profile} = await cdp.send('Profiler.stop');
    logs.push('WebGL parameter queries: '+JSON.stringify(await page.evaluate(()=>window.__glQueries)));
    const top=profile.nodes.filter(n=>n.hitCount).sort((a,b)=>b.hitCount-a.hitCount).slice(0,25);
    fs.writeFileSync(path.join(output,'cpu-profile-top.json'),JSON.stringify(top,null,2));
   }
   timings.sort((a,b)=>a-b);
   logs.push('browser RAF frame ms: median='+timings[60].toFixed(1)+', p95='+timings[114].toFixed(1));
   const glStateValid = await page.evaluate(()=>{
    const gl=document.getElementById('canvas').getContext('webgl2');
    const prior=gl.isEnabled(gl.SCISSOR_TEST);
    gl.enable(gl.SCISSOR_TEST);
    const enabled=gl.getParameter(gl.SCISSOR_TEST)===gl.isEnabled(gl.SCISSOR_TEST);
    gl.disable(gl.SCISSOR_TEST);
    const disabled=gl.getParameter(gl.SCISSOR_TEST)===gl.isEnabled(gl.SCISSOR_TEST);
    gl[prior?'enable':'disable'](gl.SCISSOR_TEST);
    return enabled && disabled;
   });
   logs.push('WebGL scissor state matches driver: '+glStateValid);
   if(!glStateValid) errors.push('WebGL scissor state cache mismatch');

   await page.setViewportSize({width:390,height:844});
   await page.waitForTimeout(700); await snap('08-portrait');
   await page.setViewportSize(viewport);
   await page.waitForTimeout(700); await snap('09-restored');
  }
 } finally {
  fs.writeFileSync(path.join(output,'browser.log'),logs.join('\n')+'\n');
  fs.writeFileSync(path.join(output,'errors.json'),JSON.stringify(errors,null,2));
  await browser.close();
 }
 console.log('Browser capture complete; errors='+errors.length+'; output='+output);
 if(errors.length) { console.log(errors.slice(0,10).join('\n')); process.exitCode=1; }
})().catch(error=>{console.error(error);process.exitCode=1;});
