ObjC.import('Cocoa')

var APP = Application.currentApplication()
APP.includeStandardAdditions = true

var state = {
  resourceDir:'', binDir:'', ytdlp:'', deno:'', denoZip:'', ffmpeg:'', ffprobe:'', arch:'', outputDir:'',
  task:null, mode:'idle', activeJobId:0, timer:null, pendingBootstrap:false,
  logPath:'', logOffset:0, logText:'', logWindow:null, logView:null,
  urlField:null, quality:null, cookies:null, statusLabel:null, topHint:null, pathLabel:null,
  queueDoc:null, queueScroll:null, queueCountLabel:null, queueHintLabel:null,
  downloadAllBtn:null, clearBtn:null, jobs:[], nextId:1, thumbSerial:1,
  lastPasteboardChange:-1, clipboardURL:'', pasteBtn:null, filterControl:null, filter:'all',
  aboutWindow:null, denoCacheDir:''
}

var BUILD = {
  version:'__YTDock_VERSION__',
  ytdlpVersion:'2026.08.19',
  ytdlpSha256:'0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202',
  denoVersion:'2.9.7',
  denoSha256:{arm64:'5cd46d6268f6f78f5d88bdc7159d20bd44cdaa4b3303474839f87ec6fe7ae25c',x86_64:'95daaff11c116a52ad54785e7914c8e9c9cdcaba793c5ed929c74ca2d8e6259a'},
  ffmpegVersion:'6.1.1',
  ffmpegSha256:{arm64:'a90e3db6a3fd35f6074b013f948b1aa45b31c6375489d39e572bea3f18336584',x86_64:'ebdddc936f61e14049a2d4b549a412b8a40deeff6540e58a9f2a2da9e6b18894'},
  ffprobeSha256:{arm64:'bb2db6f5d8cef919da12fbf592119a987202a8c060a886f3cab091f9cab90b64',x86_64:'fa3add0ce901f7241abe0dfc0155d958fc834aca3f8ce61f87cc712ae669c1e0'}
}

function js(v){ try{return ObjC.unwrap(v)}catch(e){return String(v)} }
function ns(s){ return $(String(s)) }
function fm(){ return $.NSFileManager.defaultManager }
function home(){ return js($.NSHomeDirectory()) }
function exists(p){ return !!(p && fm().fileExistsAtPath(ns(p))) }
function ensureDir(p){ fm().createDirectoryAtPathWithIntermediateDirectoriesAttributesError(ns(p),true,null,null) }
function removeFile(p){ try{ if(p && exists(p)) fm().removeItemAtPathError(ns(p),null) }catch(e){} }
function trim(s){ return String(s||'').replace(/^\s+|\s+$/g,'') }
function shellQuote(s){ return "'"+String(s).replace(/'/g,"'\\''")+"'" }
function sha256File(p){ try{var out=trim(APP.doShellScript('/usr/bin/shasum -a 256 '+shellQuote(p)));return out.split(/\s+/)[0].toLowerCase()}catch(e){appendLog('SHA-256 计算失败：'+e+'\n');return''} }
function verifyHash(p,expected,labelName){var got=sha256File(p);var ok=!!got&&got===String(expected||'').toLowerCase();appendLog((ok?'✓ ':'✗ ')+(labelName||'文件')+' SHA-256 '+(ok?'验证通过':'验证失败')+'\n');if(!ok)appendLog('  expected '+expected+'\n  actual   '+(got||'unknown')+'\n');return ok}
function removeTree(p){ try{if(p&&exists(p))fm().removeItemAtPathError(ns(p),null)}catch(e){} }
function setStatus(s){ if(state.statusLabel) state.statusLabel.stringValue=ns(s) }
function setHint(s){ if(state.topHint) state.topHint.stringValue=ns(s) }
function colorAlpha(c,a){ try{return c.colorWithAlphaComponent(a)}catch(e){return c} }
function font(size,weight){ try{return $.NSFont.systemFontOfSizeWeight(size,weight)}catch(e){return weight>0?$.NSFont.boldSystemFontOfSize(size):$.NSFont.systemFontOfSize(size)} }
function symbol(name,size,weight){
  try{
    var img=$.NSImage.imageWithSystemSymbolNameAccessibilityDescription(ns(name),ns(name))
    if(img && img.imageWithSymbolConfiguration){
      var cfg=$.NSImageSymbolConfiguration.configurationWithPointSizeWeight(size||16,weight||$.NSFontWeightRegular)
      img=img.imageWithSymbolConfiguration(cfg)
    }
    return img
  }catch(e){return null}
}
function addSymbolButtonImage(btn,name){ var img=symbol(name,14,$.NSFontWeightMedium); if(img){btn.image=img;btn.imagePosition=$.NSImageLeading;btn.imageScaling=$.NSImageScaleProportionallyDown} }
function label(text,x,y,w,h,size,weight,color){
  var v=$.NSTextField.alloc.initWithFrame($.NSMakeRect(x,y,w,h)); v.stringValue=ns(text)
  v.bezeled=false;v.drawsBackground=false;v.editable=false;v.selectable=false
  v.font=font(size||13,weight===undefined?$.NSFontWeightRegular:weight)
  try{v.textColor=color||$.NSColor.labelColor}catch(e){}
  v.lineBreakMode=$.NSLineBreakByTruncatingTail
  return v
}
function card(x,y,w,h,radius){
  var b=$.NSBox.alloc.initWithFrame($.NSMakeRect(x,y,w,h)); b.boxType=$.NSBoxCustom;b.borderType=$.NSNoBorder;b.borderWidth=0;b.cornerRadius=radius||18
  try{b.fillColor=$.NSColor.controlBackgroundColor}catch(e){}
  return b
}
function separator(x,y,w){ var v=$.NSBox.alloc.initWithFrame($.NSMakeRect(x,y,w,1));v.boxType=$.NSBoxSeparator;return v }
function button(title,x,y,w,h,target,action,imageName){
  var b=$.NSButton.alloc.initWithFrame($.NSMakeRect(x,y,w,h));b.title=ns(title);b.bezelStyle=$.NSBezelStyleRounded;b.font=font(12,$.NSFontWeightMedium);b.target=target;b.action=action
  if(imageName)addSymbolButtonImage(b,imageName);return b
}
function primaryButton(title,x,y,w,h,target,action,imageName){ var b=button(title,x,y,w,h,target,action,imageName);try{b.bezelStyle=$.NSBezelStyleTexturedRounded}catch(e){};return b }
function iconButton(name,x,y,w,h,target,action,tip){
  var b=$.NSButton.alloc.initWithFrame($.NSMakeRect(x,y,w,h));b.title=$('');b.bezelStyle=$.NSBezelStyleTexturedRounded;b.target=target;b.action=action
  var img=symbol(name,14,$.NSFontWeightMedium);if(img)b.image=img;if(tip)b.toolTip=ns(tip);return b
}
function popup(items,x,y,w,h){ var p=$.NSPopUpButton.alloc.initWithFramePullsDown($.NSMakeRect(x,y,w,h),false);p.addItemsWithTitles($(items));p.font=font(12,$.NSFontWeightRegular);return p }
function badge(text,x,y,w){
  var v=label(text,x,y,w,22,11,$.NSFontWeightMedium,$.NSColor.secondaryLabelColor);v.alignment=$.NSTextAlignmentCenter;v.wantsLayer=true
  try{v.layer.cornerRadius=10;v.layer.backgroundColor=colorAlpha($.NSColor.secondaryLabelColor,0.08).CGColor}catch(e){};return v
}
function statusChip(text,x,y,w,color){
  var v=label(text,x,y,w,22,10,$.NSFontWeightSemibold,color||$.NSColor.secondaryLabelColor);v.alignment=$.NSTextAlignmentCenter;v.wantsLayer=true
  try{v.layer.cornerRadius=10;v.layer.backgroundColor=colorAlpha(color||$.NSColor.secondaryLabelColor,0.10).CGColor}catch(e){};return v
}
function removeSubviews(view){ try{while(Number(view.subviews.count)>0)view.subviews.objectAtIndex(0).removeFromSuperview()}catch(e){} }

function makeLogPath(suffix){ var p=js($.NSTemporaryDirectory())+'YTDock-'+(suffix||'run')+'-'+String(Date.now())+'.log';removeFile(p);fm().createFileAtPathContentsAttributes(ns(p),$.NSData.data,null);return p }
function appendLog(s){
  state.logText+=String(s);if(state.logText.length>80000)state.logText=state.logText.slice(state.logText.length-80000)
  if(state.logView){state.logView.string=ns(state.logText);try{state.logView.scrollRangeToVisible($.NSMakeRange(state.logView.string.length,0))}catch(e){}}
  parseTaskOutput(String(s))
}
function shellTask(path,args,logPath){
  var task=$.NSTask.alloc.init;task.launchPath=ns(path);task.arguments=$(args.map(String))
  try{var env=$.NSProcessInfo.processInfo.environment.mutableCopy;if(state.denoCacheDir)env.setObjectForKey(ns(state.denoCacheDir),ns('DENO_DIR'));env.setObjectForKey(ns('1'),ns('PYTHONNOUSERSITE'));task.environment=env}catch(e){}
  var handle=$.NSFileHandle.fileHandleForWritingAtPath(ns(logPath));if(!handle){fm().createFileAtPathContentsAttributes(ns(logPath),$.NSData.data,null);handle=$.NSFileHandle.fileHandleForWritingAtPath(ns(logPath))}
  handle.truncateFileAtOffset(0);task.standardOutput=handle;task.standardError=handle;task.launch;return task
}
function readLogDelta(){
  if(!exists(state.logPath))return
  var data=$.NSData.dataWithContentsOfFile(ns(state.logPath));if(!data)return
  var total=Number(data.length);if(total<=state.logOffset)return
  var sub=data.subdataWithRange($.NSMakeRange(state.logOffset,total-state.logOffset));var str=$.NSString.alloc.initWithDataEncoding(sub,$.NSUTF8StringEncoding)
  if(str)appendLog(js(str));state.logOffset=total
}
function bundleWritable(){ try{return Boolean(fm().isWritableFileAtPath(ns(state.resourceDir)))}catch(e){return false} }
function chmod755(p){ var t=$.NSTask.alloc.init;t.launchPath='/bin/chmod';t.arguments=$(['755',p]);t.launch;t.waitUntilExit }
function toolsReady(){ return exists(state.ytdlp)&&exists(state.deno)&&exists(state.ffmpeg)&&exists(state.ffprobe) }

function qualityFormat(){
  var i=Number(state.quality.indexOfSelectedItem)
  if(i===0)return 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best'
  if(i===1)return 'bestvideo[height<=2160]+bestaudio/best[height<=2160]/best'
  if(i===2)return 'bestvideo[height<=1080]+bestaudio/best[height<=1080]/best'
  if(i===3)return 'bestvideo[height<=720]+bestaudio/best[height<=720]/best'
  if(i===4)return 'bestaudio[ext=m4a]/bestaudio'
  return 'bestvideo+bestaudio/best'
}
function qualityName(){ try{return js(state.quality.titleOfSelectedItem)}catch(e){return '最佳质量'} }
function cookieArgs(){ var i=Number(state.cookies.indexOfSelectedItem);if(i===1)return['--cookies-from-browser','safari'];if(i===2)return['--cookies-from-browser','chrome'];if(i===3)return['--cookies-from-browser','firefox'];return[] }
function humanDuration(v){ if(!v)return'';if(typeof v==='string')return v;var n=Math.floor(Number(v)||0),h=Math.floor(n/3600),m=Math.floor((n%3600)/60),s=n%60;return h?(h+':'+String(m).padStart(2,'0')+':'+String(s).padStart(2,'0')):(m+':'+String(s).padStart(2,'0')) }
function cleanURL(s){ return trim(String(s||'').replace(/[\]\[(){}<>"'，。；、]+$/g,'')) }
function parseLinks(text){
  var raw=String(text||''),m,links=[],re=/https?:\/\/[^\s]+/g
  while((m=re.exec(raw))!==null){var u=cleanURL(m[0]);if(u&&links.indexOf(u)<0)links.push(u)}
  if(!links.length&&/^https?:\/\//.test(trim(raw)))links=[cleanURL(raw)]
  return links
}
function jobById(id){ for(var i=0;i<state.jobs.length;i++)if(state.jobs[i].id===Number(id))return state.jobs[i];return null }
function activeJob(){ return jobById(state.activeJobId) }
function jobStatusText(job){
  if(job.status==='queued')return'等待解析';if(job.status==='parsing')return'解析中';if(job.status==='thumb')return'读取封面';if(job.status==='ready')return'可下载';
  if(job.status==='waiting')return'等待下载';if(job.status==='downloading')return'下载中';if(job.status==='done')return'已完成';if(job.status==='error')return'失败';if(job.status==='cancelled')return'已取消';return'等待'
}
function jobStatusColor(job){
  try{if(job.status==='done')return $.NSColor.systemGreenColor;if(job.status==='error')return $.NSColor.systemRedColor;if(job.status==='downloading'||job.status==='parsing'||job.status==='thumb')return $.NSColor.controlAccentColor;if(job.status==='waiting')return $.NSColor.systemOrangeColor}catch(e){}
  return $.NSColor.secondaryLabelColor
}
function jobSymbol(job){ if(job.status==='done')return'checkmark.circle.fill';if(job.status==='error')return'exclamationmark.triangle.fill';if(job.status==='downloading')return'arrow.down.circle.fill';if(job.status==='parsing'||job.status==='thumb')return'sparkles';if(job.status==='waiting')return'clock.fill';return'play.rectangle.fill' }
function jobDetail(job){
  if(job.status==='downloading')return (job.speed||'—')+(job.eta?'  ·  剩余 '+job.eta:'')
  if(job.status==='done')return job.finalPath?'已保存 · '+state.outputDir:'已保存到 '+state.outputDir
  if(job.status==='error')return job.error||'打开详情查看原因'
  if(job.status==='cancelled')return'任务已取消，可重新下载'
  if(job.status==='ready')return'准备下载  ·  '+qualityName()
  if(job.status==='waiting')return'将在当前任务完成后自动开始'
  if(job.status==='queued')return'等待读取标题与来源'
  if(job.status==='parsing')return'正在读取视频信息…'
  if(job.status==='thumb')return'正在加载缩略图…'
  return''
}
function countSummary(){
  var active=0,done=0,errors=0
  for(var i=0;i<state.jobs.length;i++){var s=state.jobs[i].status;if(s==='downloading'||s==='parsing'||s==='thumb'||s==='waiting'||s==='queued')active++;if(s==='done')done++;if(s==='error')errors++}
  if(!state.jobs.length)return'暂无任务'
  var bits=[state.jobs.length+' 个任务'];if(active)bits.push(active+' 个进行/等待');if(done)bits.push(done+' 个完成');if(errors)bits.push(errors+' 个失败');return bits.join('  ·  ')
}
function updateHeader(){
  if(state.queueCountLabel)state.queueCountLabel.stringValue=ns(countSummary())
  if(state.downloadAllBtn){var any=false;for(var i=0;i<state.jobs.length;i++)if(['ready','queued','parsing','thumb','error','cancelled'].indexOf(state.jobs[i].status)>=0){any=true;break}state.downloadAllBtn.enabled=any}
  if(state.clearBtn){var can=false;for(var j=0;j<state.jobs.length;j++)if(['done','error','cancelled'].indexOf(state.jobs[j].status)>=0){can=true;break}state.clearBtn.enabled=can}
}
function updateJobUI(job){
  if(!job)return
  try{
    if(job.uiTitle)job.uiTitle.stringValue=ns(job.title||'等待解析链接')
    if(job.uiMeta)job.uiMeta.stringValue=ns(job.meta||job.url)
    if(job.uiProgress){job.uiProgress.doubleValue=job.progress||0;job.uiProgress.hidden=!(job.status==='downloading'||job.status==='done'||job.status==='waiting')}
    if(job.uiPct){job.uiPct.stringValue=ns(job.status==='done'?'完成':((job.status==='downloading'||job.status==='waiting')?((job.progress||0).toFixed(job.progress>=10?0:1)+'%'):' '))}
    if(job.uiDetail)job.uiDetail.stringValue=ns(jobDetail(job))
    if(job.uiChip){job.uiChip.stringValue=ns(jobStatusText(job));job.uiChip.textColor=jobStatusColor(job);job.uiChip.layer.backgroundColor=colorAlpha(jobStatusColor(job),0.10).CGColor}
    if(job.uiThumb && job.image){job.uiThumb.image=job.image;job.uiThumb.imageScaling=$.NSImageScaleAxesIndependently}
    if(job.uiAction){
      if(job.status==='done'){job.uiAction.title=$('Finder');job.uiAction.enabled=true}
      else if(job.status==='downloading'||job.status==='parsing'||job.status==='thumb'){job.uiAction.title=$('取消');job.uiAction.enabled=true}
      else if(job.status==='queued'){job.uiAction.title=$('等待');job.uiAction.enabled=false}
      else if(job.status==='waiting'){job.uiAction.title=$('取消等待');job.uiAction.enabled=true}
      else{job.uiAction.title=ns(job.status==='error'||job.status==='cancelled'?'重试':'下载');job.uiAction.enabled=true}
    }
    if(job.uiRemove)job.uiRemove.enabled=!(state.activeJobId===job.id && state.task && state.task.running)
  }catch(e){}
  updateHeader()
}
function renderQueue(actions){
  if(!state.queueDoc)return
  removeSubviews(state.queueDoc)
  var W=824,cardH=112,gap=12
  if(!state.jobs.length){
    var h=326;state.queueDoc.frame=$.NSMakeRect(0,0,W,h)
    var empty=card(0,20,W,286,20);state.queueDoc.addSubview(empty)
    var ic=$.NSImageView.alloc.initWithFrame($.NSMakeRect(354,161,116,72));ic.image=symbol('square.stack.3d.up.slash',46,$.NSFontWeightLight);ic.imageScaling=$.NSImageScaleProportionallyDown;empty.addSubview(ic)
    var t=label('队列是空的',0,126,W,28,18,$.NSFontWeightSemibold,$.NSColor.labelColor);t.alignment=$.NSTextAlignmentCenter;empty.addSubview(t)
    var s=label('粘贴一个或多个链接。YTDock 会先解析，再按你的选择下载。',100,94,W-200,24,12,$.NSFontWeightRegular,$.NSColor.secondaryLabelColor);s.alignment=$.NSTextAlignmentCenter;empty.addSubview(s)
    var tip=label('支持一次粘贴多行链接；也可将文本 URL 拖入上方输入框。',100,66,W-200,22,11,$.NSFontWeightRegular,$.NSColor.tertiaryLabelColor);tip.alignment=$.NSTextAlignmentCenter;empty.addSubview(tip)
    updateHeader();return
  }
  var total=state.jobs.length*(cardH+gap)+10;var minH=326;if(total<minH)total=minH;state.queueDoc.frame=$.NSMakeRect(0,0,W,total)
  var y=total-cardH-4
  for(var i=0;i<state.jobs.length;i++){
    var job=state.jobs[i],b=card(0,y,W,cardH,18);state.queueDoc.addSubview(b)
    var thumb=card(12,12,138,88,12);try{thumb.fillColor=$.NSColor.blackColor}catch(e){};b.addSubview(thumb)
    var iv=$.NSImageView.alloc.initWithFrame($.NSMakeRect(0,0,138,88));iv.image=job.image||symbol(jobSymbol(job),38,$.NSFontWeightRegular);iv.imageScaling=job.image?$.NSImageScaleAxesIndependently:$.NSImageScaleProportionallyDown;thumb.addSubview(iv);job.uiThumb=iv
    job.uiTitle=label(job.title||'等待解析链接',168,75,444,24,14,$.NSFontWeightSemibold,$.NSColor.labelColor);b.addSubview(job.uiTitle)
    job.uiMeta=label(job.meta||job.url,168,52,444,20,11,$.NSFontWeightRegular,$.NSColor.secondaryLabelColor);b.addSubview(job.uiMeta)
    job.uiProgress=$.NSProgressIndicator.alloc.initWithFrame($.NSMakeRect(168,31,444,6));job.uiProgress.indeterminate=false;job.uiProgress.minValue=0;job.uiProgress.maxValue=100;job.uiProgress.doubleValue=job.progress||0;job.uiProgress.style=$.NSProgressIndicatorStyleBar;b.addSubview(job.uiProgress)
    job.uiPct=label('',168,10,58,18,10,$.NSFontWeightSemibold,$.NSColor.labelColor);b.addSubview(job.uiPct)
    job.uiDetail=label(jobDetail(job),224,9,388,18,10,$.NSFontWeightRegular,$.NSColor.secondaryLabelColor);job.uiDetail.alignment=$.NSTextAlignmentRight;b.addSubview(job.uiDetail)
    job.uiChip=statusChip(jobStatusText(job),626,74,92,22,jobStatusColor(job));b.addSubview(job.uiChip)
    job.uiAction=button('下载',626,30,118,32,actions,'jobAction:',null);job.uiAction.tag=job.id;b.addSubview(job.uiAction)
    job.uiRemove=iconButton('xmark',752,30,48,32,actions,'removeJob:','从队列移除');job.uiRemove.tag=job.id;b.addSubview(job.uiRemove)
    updateJobUI(job);y-=cardH+gap
  }
  updateHeader()
}
function parseTaskOutput(text){
  var job=activeJob();if(!job)return
  if(state.mode==='download'){
    var re=/YTDPROGRESS:\s*([0-9.]+)%\|([^|\r\n]*)\|([^\r\n]*)/g,m,last=null
    while((m=re.exec(text))!==null)last=m
    if(last){job.progress=Math.max(0,Math.min(100,parseFloat(last[1])||0));job.speed=trim(last[2]);job.eta=trim(last[3]);updateJobUI(job)}
    var out=/YTDOUTPUT:([^\r\n]+)/g,om,ol=null;while((om=out.exec(text))!==null)ol=om;if(ol)job.finalPath=trim(ol[1])
  }
}
function addJobs(text,actions,autoDownload){
  var links=parseLinks(text);if(!links.length){setStatus('没有检测到链接');setHint('请粘贴 http 或 https 链接');return 0}
  var added=0
  for(var i=0;i<links.length;i++){
    var duplicate=false;for(var j=0;j<state.jobs.length;j++)if(state.jobs[j].url===links[i]&&state.jobs[j].status!=='error'&&state.jobs[j].status!=='cancelled'){duplicate=true;break}
    if(duplicate)continue
    state.jobs.push({id:state.nextId++,url:links[i],title:'等待解析链接',meta:links[i],status:'queued',progress:0,speed:'',eta:'',error:'',thumbnail:'',thumbPath:'',image:null,autoDownload:!!autoDownload,finalPath:''});added++
  }
  if(added){state.urlField.stringValue=$('');renderQueue(actions);setStatus('已加入队列');setHint(added+' 个链接已加入');processQueue(actions)}
  else{setStatus('链接已在队列中');setHint('不会重复添加同一个活动任务')}
  return added
}
function startBootstrap(actions){
  if(state.task&&state.task.running)return
  if(!bundleWritable()){
    setStatus('请复制到“应用程序”');setHint('DMG 是只读的；复制后首次初始化只写入 App 自身')
    for(var i=0;i<state.jobs.length;i++)if(state.jobs[i].status==='queued'){state.jobs[i].error='请先把 YTDock.app 拖到“应用程序”';updateJobUI(state.jobs[i])}
    return
  }
  ensureDir(state.binDir);state.pendingBootstrap=true
  if(!exists(state.ytdlp)){
    state.logPath=makeLogPath('bootstrap-ytdlp');state.logOffset=0;appendLog('\n— 初始化 yt-dlp —\n');state.mode='bootstrap-ytdlp';state.activeJobId=0
    state.task=shellTask('/usr/bin/curl',['-L','--fail','--retry','2','--connect-timeout','15','-o',state.ytdlp,'https://github.com/yt-dlp/yt-dlp/releases/download/'+BUILD.ytdlpVersion+'/yt-dlp_macos'],state.logPath)
    setStatus('初始化下载引擎…');setHint('首次运行只需一次');return
  }
  startDenoBootstrap(actions)
}
function startDenoBootstrap(actions){
  if(exists(state.deno)){startFFmpegBootstrap(actions);return}
  state.logPath=makeLogPath('bootstrap-deno');state.logOffset=0;appendLog('\n— 初始化 Deno —\n');state.mode='bootstrap-deno';state.activeJobId=0
  var asset=state.arch==='arm64'?'deno-aarch64-apple-darwin.zip':'deno-x86_64-apple-darwin.zip'
  state.task=shellTask('/usr/bin/curl',['-L','--fail','--retry','2','--connect-timeout','15','-o',state.denoZip,'https://github.com/denoland/deno/releases/download/v'+BUILD.denoVersion+'/'+asset],state.logPath)
  setStatus('初始化 JavaScript runtime…')
}
function startFFmpegBootstrap(actions){
  if(exists(state.ffmpeg)){startFFprobeBootstrap(actions);return}
  state.logPath=makeLogPath('bootstrap-ffmpeg');state.logOffset=0;appendLog('\n— 初始化 FFmpeg —\n');state.mode='bootstrap-ffmpeg';state.activeJobId=0
  var a=state.arch==='arm64'?'arm64':'x64'
  state.task=shellTask('/usr/bin/curl',['-L','--fail','--retry','2','--connect-timeout','15','-o',state.ffmpeg,'https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffmpeg-darwin-'+a],state.logPath)
  setStatus('初始化媒体合并引擎…');setHint('首次运行会校验 FFmpeg 完整性')
}
function startFFprobeBootstrap(actions){
  if(exists(state.ffprobe)){state.pendingBootstrap=false;setStatus('就绪');processQueue(actions);return}
  state.logPath=makeLogPath('bootstrap-ffprobe');state.logOffset=0;appendLog('\n— 初始化 FFprobe —\n');state.mode='bootstrap-ffprobe';state.activeJobId=0
  var a=state.arch==='arm64'?'arm64':'x64'
  state.task=shellTask('/usr/bin/curl',['-L','--fail','--retry','2','--connect-timeout','15','-o',state.ffprobe,'https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffprobe-darwin-'+a],state.logPath)
  setStatus('初始化媒体探测引擎…')
}
function startMetadataJob(job){
  job.status='parsing';job.error='';job.progress=0;state.activeJobId=job.id;updateJobUI(job)
  state.logPath=makeLogPath('meta-'+job.id);state.logOffset=0;appendLog('\n— 解析任务 #'+job.id+' —\n'+job.url+'\n');state.mode='metadata'
  var args=['--ignore-config','--no-cache-dir','--quiet','--no-warnings','--skip-download','--dump-single-json','--no-playlist','--js-runtimes','deno:'+state.deno].concat(cookieArgs()).concat([job.url])
  state.task=shellTask(state.ytdlp,args,state.logPath);setStatus('解析中');setHint(job.title==='等待解析链接'?'正在读取链接信息':job.title)
}
function applyMetadata(job,o,actions){
  job.title=o.title||'未命名视频';var site=o.webpage_url_domain||o.extractor_key||o.extractor||'视频',uploader=o.uploader||o.channel||'',dur=o.duration_string||humanDuration(o.duration),pieces=[site]
  if(uploader)pieces.push(uploader);if(dur)pieces.push(dur);job.meta=pieces.join('  ·  ');job.thumbnail=o.thumbnail?String(o.thumbnail):'';job.error=''
  if(job.thumbnail){job.status='thumb';updateJobUI(job);startThumbnailJob(job);return}
  job.status=job.autoDownload?'waiting':'ready';updateJobUI(job);processQueue(actions)
}
function startThumbnailJob(job){
  job.thumbPath=js($.NSTemporaryDirectory())+'YTDock-thumb-'+job.id+'-'+(state.thumbSerial++)+'.jpg';removeFile(job.thumbPath)
  state.activeJobId=job.id;state.logPath=makeLogPath('thumb-'+job.id);state.logOffset=0;state.mode='thumbnail'
  state.task=shellTask('/usr/bin/curl',['-L','--fail','--silent','--max-time','12','-o',job.thumbPath,job.thumbnail],state.logPath)
}
function loadThumbnail(job){ try{if(exists(job.thumbPath)){var img=$.NSImage.alloc.initWithContentsOfFile(ns(job.thumbPath));if(img)job.image=img}}catch(e){};removeFile(job.thumbPath);job.thumbPath='';updateJobUI(job) }
function startDownloadJob(job){
  job.status='downloading';job.progress=0;job.speed='';job.eta='';job.error='';state.activeJobId=job.id;updateJobUI(job)
  state.logPath=makeLogPath('download-'+job.id);state.logOffset=0;appendLog('\n— 下载任务 #'+job.id+' —\n'+job.url+'\n');state.mode='download'
  var args=['--ignore-config','--no-cache-dir','--newline','--no-colors','--no-playlist','--trim-filenames','180','--paths',state.outputDir,'--output','%(title)s [%(id)s].%(ext)s','--format',qualityFormat(),
    '--ffmpeg-location',state.ffmpeg,'--progress-template','download:YTDPROGRESS:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s','--print','after_move:YTDOUTPUT:%(filepath)s','--js-runtimes','deno:'+state.deno]
    .concat(cookieArgs()).concat([job.url])
  state.task=shellTask(state.ytdlp,args,state.logPath);setStatus('下载中');setHint(job.title)
}
function processQueue(actions){
  if(state.task&&state.task.running)return
  if(state.pendingBootstrap)return
  var need=false;for(var i=0;i<state.jobs.length;i++)if(['queued','waiting'].indexOf(state.jobs[i].status)>=0){need=true;break}
  if(need&&!toolsReady()){startBootstrap(actions);return}
  var j
  for(i=0;i<state.jobs.length;i++)if(state.jobs[i].status==='waiting'){j=state.jobs[i];break}
  if(j){startDownloadJob(j);return}
  for(i=0;i<state.jobs.length;i++)if(state.jobs[i].status==='queued'){j=state.jobs[i];break}
  if(j){startMetadataJob(j);return}
  state.activeJobId=0;setStatus(toolsReady()?'就绪':'首次配置');setHint(state.jobs.length?'队列已处理完毕':'粘贴链接即可开始')
}
function finishTask(code,actions){
  readLogDelta();var mode=state.mode,job=activeJob();state.task=null;state.mode='idle'
  if(mode==='bootstrap-ytdlp'){
    if(code===0&&exists(state.ytdlp)&&verifyHash(state.ytdlp,BUILD.ytdlpSha256,'yt-dlp')){chmod755(state.ytdlp);appendLog('✓ yt-dlp '+BUILD.ytdlpVersion+' 就绪\n');startDenoBootstrap(actions);return}
    removeFile(state.ytdlp);state.pendingBootstrap=false;setStatus('完整性验证失败');setHint('已拒绝使用下载到的引擎；打开详情查看原因');return
  }
  if(mode==='bootstrap-deno'){
    var expectedDeno=BUILD.denoSha256[state.arch]||''
    if(code===0&&exists(state.denoZip)&&verifyHash(state.denoZip,expectedDeno,'Deno '+state.arch)){
      try{var u=$.NSTask.alloc.init;u.launchPath='/usr/bin/unzip';u.arguments=$(['-o',state.denoZip,'-d',state.binDir]);u.launch;u.waitUntilExit;if(exists(state.binDir+'/deno')){if(state.deno!==state.binDir+'/deno')fm().moveItemAtPathToPathError(ns(state.binDir+'/deno'),ns(state.deno),null);chmod755(state.deno)}}catch(e){appendLog('Deno 解压失败：'+e+'\n')}
      removeFile(state.denoZip);if(exists(state.deno)){appendLog('✓ Deno '+BUILD.denoVersion+' 就绪\n');startFFmpegBootstrap(actions);return}
    }
    removeFile(state.denoZip);removeFile(state.deno);state.pendingBootstrap=false;setStatus('完整性验证失败');setHint('已拒绝使用下载到的 runtime；打开详情查看原因');return
  }
  if(mode==='bootstrap-ffmpeg'){
    if(code===0&&exists(state.ffmpeg)&&verifyHash(state.ffmpeg,BUILD.ffmpegSha256[state.arch]||'', 'FFmpeg '+state.arch)){chmod755(state.ffmpeg);appendLog('✓ FFmpeg '+BUILD.ffmpegVersion+' 就绪\n');startFFprobeBootstrap(actions);return}
    removeFile(state.ffmpeg);state.pendingBootstrap=false;setStatus('完整性验证失败');setHint('已拒绝使用下载到的 FFmpeg；打开详情查看原因');return
  }
  if(mode==='bootstrap-ffprobe'){
    if(code===0&&exists(state.ffprobe)&&verifyHash(state.ffprobe,BUILD.ffprobeSha256[state.arch]||'', 'FFprobe '+state.arch)){chmod755(state.ffprobe);appendLog('✓ FFprobe '+BUILD.ffmpegVersion+' 就绪\n');state.pendingBootstrap=false;setStatus('就绪');processQueue(actions);return}
    removeFile(state.ffprobe);state.pendingBootstrap=false;setStatus('完整性验证失败');setHint('已拒绝使用下载到的 FFprobe；打开详情查看原因');return
  }
  if(!job){processQueue(actions);return}
  if(mode==='metadata'){
    if(job.status==='cancelled'){updateJobUI(job);processQueue(actions);return}
    if(code===0){
      try{var raw=js($.NSString.stringWithContentsOfFileEncodingError(ns(state.logPath),$.NSUTF8StringEncoding,null)),start=raw.indexOf('{'),end=raw.lastIndexOf('}');if(start>=0&&end>start){applyMetadata(job,JSON.parse(raw.slice(start,end+1)),actions);return}}catch(e){appendLog('解析 JSON 失败：'+e+'\n')}
    }
    job.status='error';job.error='无法解析链接；可尝试切换 Cookies';updateJobUI(job);processQueue(actions);return
  }
  if(mode==='thumbnail'){
    if(job.status==='cancelled'){removeFile(job.thumbPath);job.thumbPath='';updateJobUI(job);processQueue(actions);return}
    loadThumbnail(job);job.status=job.autoDownload?'waiting':'ready';updateJobUI(job);processQueue(actions);return
  }
  if(mode==='download'){
    if(code===0){job.status='done';job.progress=100;job.error='';appendLog('✓ 下载完成\n')}
    else if(job.status==='cancelled'){appendLog('— 已取消 —\n')}
    else{job.status='error';job.error='下载失败，打开详情查看原因';appendLog('✗ 下载失败，错误码：'+code+'\n')}
    updateJobUI(job);processQueue(actions);return
  }
  processQueue(actions)
}
function openAboutWindow(){
  if(state.aboutWindow){state.aboutWindow.makeKeyAndOrderFront(null);return}
  var style=$.NSWindowStyleMaskTitled|$.NSWindowStyleMaskClosable,w=$.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer($.NSMakeRect(0,0,520,420),style,$.NSBackingStoreBuffered,false)
  w.title=$('关于 YTDock');w.center;var c=w.contentView
  var iv=$.NSImageView.alloc.initWithFrame($.NSMakeRect(206,326,108,62));iv.image=symbol('arrow.down.circle.fill',54,$.NSFontWeightRegular);iv.imageScaling=$.NSImageScaleProportionallyDown;c.addSubview(iv)
  var name=label('YTDock',0,292,520,32,24,$.NSFontWeightBold,$.NSColor.labelColor);name.alignment=$.NSTextAlignmentCenter;c.addSubview(name)
  var ver=label('Version '+BUILD.version+'  ·  免费分发构建',0,265,520,22,12,$.NSFontWeightMedium,$.NSColor.secondaryLabelColor);ver.alignment=$.NSTextAlignmentCenter;c.addSubview(ver)
  var box=card(32,98,456,146,16);c.addSubview(box)
  box.addSubview(label('隐私与安全',18,108,180,22,13,$.NSFontWeightSemibold,$.NSColor.labelColor))
  box.addSubview(label('• 不保存下载历史或链接数据库',18,82,410,20,11,$.NSFontWeightRegular,$.NSColor.secondaryLabelColor))
  box.addSubview(label('• 不安装后台服务、LaunchAgent 或特权辅助程序',18,58,410,20,11,$.NSFontWeightRegular,$.NSColor.secondaryLabelColor))
  box.addSubview(label('• yt-dlp / Deno 固定版本并在首次获取时校验 SHA-256',18,34,410,20,11,$.NSFontWeightRegular,$.NSColor.secondaryLabelColor))
  box.addSubview(label('• 免费构建不含 Developer ID / Apple notarization',18,10,410,20,11,$.NSFontWeightRegular,$.NSColor.secondaryLabelColor))
  var deps=label('yt-dlp '+BUILD.ytdlpVersion+'   ·   Deno '+BUILD.denoVersion+'   ·   FFmpeg '+BUILD.ffmpegVersion,0,62,520,22,11,$.NSFontWeightRegular,$.NSColor.tertiaryLabelColor);deps.alignment=$.NSTextAlignmentCenter;c.addSubview(deps)
  var foot=label('仅下载你有权保存的内容',0,34,520,22,10,$.NSFontWeightRegular,$.NSColor.tertiaryLabelColor);foot.alignment=$.NSTextAlignmentCenter;c.addSubview(foot)
  state.aboutWindow=w;w.makeKeyAndOrderFront(null)
}
function openLogWindow(){
  if(state.logWindow){state.logWindow.makeKeyAndOrderFront(null);return}
  var style=$.NSWindowStyleMaskTitled|$.NSWindowStyleMaskClosable|$.NSWindowStyleMaskResizable,w=$.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer($.NSMakeRect(0,0,720,430),style,$.NSBackingStoreBuffered,false)
  w.title=$('YTDock · 运行详情');w.minSize=$.NSMakeSize(540,320);w.center;var c=w.contentView
  c.addSubview(label('运行详情',22,380,220,28,18,$.NSFontWeightSemibold,$.NSColor.labelColor));c.addSubview(label('这里只用于排查问题；关闭窗口不会停止下载。',22,354,620,22,12,$.NSFontWeightRegular,$.NSColor.secondaryLabelColor))
  var scroll=$.NSScrollView.alloc.initWithFrame($.NSMakeRect(22,22,676,316));scroll.hasVerticalScroller=true;scroll.borderType=$.NSNoBorder
  state.logView=$.NSTextView.alloc.initWithFrame($.NSMakeRect(0,0,656,316));state.logView.editable=false;state.logView.selectable=true;state.logView.font=$.NSFont.monospacedSystemFontOfSizeWeight(11,$.NSFontWeightRegular);state.logView.string=ns(state.logText||'暂无日志。')
  scroll.documentView=state.logView;c.addSubview(scroll);state.logWindow=w;w.makeKeyAndOrderFront(null)
}
function openPath(path){ if(!path)return;var t=$.NSTask.alloc.init;t.launchPath='/usr/bin/open';t.arguments=$([path]);t.launch }
function revealPath(path){ if(!path){openPath(state.outputDir);return}var t=$.NSTask.alloc.init;t.launchPath='/usr/bin/open';t.arguments=$(['-R',path]);t.launch }

ObjC.registerSubclass({
  name:'YTDockActionsV10',
  methods:{
    'add:':{types:['void',['id']],implementation:function(sender){var t=trim(js(state.urlField.stringValue));if(!t){var p=$.NSPasteboard.generalPasteboard.stringForType($.NSPasteboardTypeString);if(p)t=js(p)};addJobs(t,this,false)}},
    'paste:':{types:['void',['id']],implementation:function(sender){var p=$.NSPasteboard.generalPasteboard.stringForType($.NSPasteboardTypeString);if(p){state.urlField.stringValue=p;addJobs(js(p),this,false)}else{setStatus('剪贴板为空');setHint('复制链接后再试')}}},
    'downloadAll:':{types:['void',['id']],implementation:function(sender){
      if(!state.jobs.length)return
      for(var i=0;i<state.jobs.length;i++){var j=state.jobs[i];if(j.status==='ready'||j.status==='error'||j.status==='cancelled'){if((j.status==='error'||j.status==='cancelled')&&(j.title==='等待解析链接'||j.meta===j.url)){j.status='queued';j.autoDownload=true}else{j.status='waiting';j.autoDownload=true}}else if(['queued','parsing','thumb'].indexOf(j.status)>=0)j.autoDownload=true;updateJobUI(j)}
      setStatus('已加入下载队列');setHint('任务会依次处理');processQueue(this)
    }},
    'jobAction:':{types:['void',['id']],implementation:function(sender){
      var j=jobById(Number(sender.tag));if(!j)return
      if(j.status==='done'){revealPath(j.finalPath);return}
      if(j.status==='downloading'||j.status==='parsing'||j.status==='thumb'){if(state.activeJobId===j.id&&state.task&&state.task.running){j.status='cancelled';j.error='';updateJobUI(j);state.task.terminate;setStatus('正在取消…')}return}
      if(j.status==='waiting'){j.status='ready';j.autoDownload=false;updateJobUI(j);return}
      if(j.status==='error'||j.status==='cancelled'){if(j.title&&j.title!=='等待解析链接'&&j.meta!==j.url){j.status='waiting';j.autoDownload=true}else{j.status='queued';j.autoDownload=true};j.error='';updateJobUI(j);processQueue(this);return}
      if(j.status==='ready'){j.status='waiting';j.autoDownload=true;updateJobUI(j);processQueue(this)}
    }},
    'removeJob:':{types:['void',['id']],implementation:function(sender){
      var id=Number(sender.tag);if(state.activeJobId===id&&state.task&&state.task.running)return
      var out=[];for(var i=0;i<state.jobs.length;i++){if(state.jobs[i].id===id){removeFile(state.jobs[i].thumbPath)}else out.push(state.jobs[i])};state.jobs=out;renderQueue(this);processQueue(this)
    }},
    'clearFinished:':{types:['void',['id']],implementation:function(sender){
      var out=[];for(var i=0;i<state.jobs.length;i++){var j=state.jobs[i];if(['done','error','cancelled'].indexOf(j.status)<0)out.push(j);else removeFile(j.thumbPath)};state.jobs=out;renderQueue(this)
    }},
    'chooseFolder:':{types:['void',['id']],implementation:function(sender){var p=$.NSOpenPanel.openPanel;p.canChooseFiles=false;p.canChooseDirectories=true;p.allowsMultipleSelection=false;if(p.runModal===$.NSModalResponseOK){state.outputDir=js(p.URL.path);state.pathLabel.stringValue=ns(state.outputDir);for(var i=0;i<state.jobs.length;i++)updateJobUI(state.jobs[i])}}},
    'openFolder:':{types:['void',['id']],implementation:function(sender){openPath(state.outputDir)}},
    'details:':{types:['void',['id']],implementation:function(sender){openLogWindow()}},
    'about:':{types:['void',['id']],implementation:function(sender){openAboutWindow()}},
    'qualityChanged:':{types:['void',['id']],implementation:function(sender){for(var i=0;i<state.jobs.length;i++)if(state.jobs[i].status==='ready')updateJobUI(state.jobs[i])}},
    'tick:':{types:['void',['id']],implementation:function(timer){
      if(state.task){readLogDelta();if(!state.task.running)finishTask(Number(state.task.terminationStatus),this)}
      try{var pb=$.NSPasteboard.generalPasteboard,cc=Number(pb.changeCount);if(cc!==state.lastPasteboardChange){state.lastPasteboardChange=cc;var s=pb.stringForType($.NSPasteboardTypeString),links=s?parseLinks(js(s)):[];state.clipboardURL=links.length?links[0]:'';if(state.pasteBtn)state.pasteBtn.title=ns(state.clipboardURL?'加入剪贴板链接':'剪贴板')}}catch(e){}
    }},
    'windowWillClose:':{types:['void',['id']],implementation:function(note){if(state.task&&state.task.running)state.task.terminate;removeFile(state.logPath);removeFile(state.denoZip);removeTree(state.denoCacheDir);for(var i=0;i<state.jobs.length;i++)removeFile(state.jobs[i].thumbPath);$.NSApp.terminate(0)}}
  }
})

function run(argv){
  state.resourceDir=argv&&argv.length?String(argv[0]):'';state.binDir=state.resourceDir+'/Tools';state.ytdlp=state.binDir+'/yt-dlp'
  try{state.arch=trim(APP.doShellScript('/usr/bin/uname -m'))}catch(e){state.arch='x86_64'}
  state.deno=state.binDir+'/deno';state.ffmpeg=state.binDir+'/ffmpeg';state.ffprobe=state.binDir+'/ffprobe';state.denoZip=js($.NSTemporaryDirectory())+'YTDock-deno.zip';state.denoCacheDir=js($.NSTemporaryDirectory())+'YTDock-Deno-'+String($.NSProcessInfo.processInfo.processIdentifier);ensureDir(state.denoCacheDir);state.outputDir=home()+'/Downloads'

  var app=$.NSApplication.sharedApplication;app.setActivationPolicy($.NSApplicationActivationPolicyRegular);var actions=$.YTDockActionsV05.alloc.init
  try{var appIcon=symbol('arrow.down.circle.fill',64,$.NSFontWeightRegular);if(appIcon)app.applicationIconImage=appIcon}catch(e){}

  var style=$.NSWindowStyleMaskTitled|$.NSWindowStyleMaskClosable|$.NSWindowStyleMaskMiniaturizable|$.NSWindowStyleMaskResizable|$.NSWindowStyleMaskFullSizeContentView
  var win=$.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer($.NSMakeRect(0,0,920,720),style,$.NSBackingStoreBuffered,false)
  win.title=$('YTDock');win.titleVisibility=$.NSWindowTitleHidden;win.titlebarAppearsTransparent=true;win.minSize=$.NSMakeSize(860,670);win.center;win.delegate=actions
  try{win.backgroundColor=$.NSColor.windowBackgroundColor}catch(e){};var c=win.contentView

  // Header
  var brandIcon=$.NSImageView.alloc.initWithFrame($.NSMakeRect(32,642,42,42));brandIcon.image=symbol('arrow.down.circle.fill',34,$.NSFontWeightSemibold);c.addSubview(brandIcon)
  c.addSubview(label('YTDock',84,658,220,28,24,$.NSFontWeightBold,$.NSColor.labelColor))
  state.topHint=label('粘贴链接即可开始',84,635,430,22,12,$.NSFontWeightRegular,$.NSColor.secondaryLabelColor);c.addSubview(state.topHint)
  var about=iconButton('info.circle',654,649,44,32,actions,'about:','关于与安全');c.addSubview(about)
  var details=iconButton('waveform.path.ecg',704,649,44,32,actions,'details:','运行详情');c.addSubview(details)
  var folder=iconButton('folder',754,649,44,32,actions,'openFolder:','打开下载文件夹');c.addSubview(folder)
  state.statusLabel=badge(toolsReady()?'就绪':'首次配置',808,654,98);c.addSubview(state.statusLabel)

  // Input hero
  var inputCard=card(32,558,856,66,18);c.addSubview(inputCard)
  var linkIcon=$.NSImageView.alloc.initWithFrame($.NSMakeRect(18,20,26,26));linkIcon.image=symbol('link',17,$.NSFontWeightMedium);inputCard.addSubview(linkIcon)
  state.urlField=$.NSTextField.alloc.initWithFrame($.NSMakeRect(50,16,482,34));state.urlField.placeholderString=$('粘贴一个或多个链接…');state.urlField.font=font(14,$.NSFontWeightRegular);state.urlField.bezelStyle=$.NSTextFieldRoundedBezel;inputCard.addSubview(state.urlField)
  state.pasteBtn=button('剪贴板',544,16,144,34,actions,'paste:','doc.on.clipboard');inputCard.addSubview(state.pasteBtn)
  var addBtn=primaryButton('加入队列',700,16,136,34,actions,'add:','plus');try{addBtn.keyEquivalent=$('\r')}catch(e){};inputCard.addSubview(addBtn)

  // Queue header
  c.addSubview(label('下载队列',32,520,160,24,14,$.NSFontWeightSemibold,$.NSColor.labelColor))
  state.queueCountLabel=label('暂无任务',130,520,380,24,11,$.NSFontWeightRegular,$.NSColor.secondaryLabelColor);c.addSubview(state.queueCountLabel)
  state.clearBtn=button('清理',636,514,86,30,actions,'clearFinished:','trash');state.clearBtn.enabled=false;c.addSubview(state.clearBtn)
  state.downloadAllBtn=primaryButton('全部下载',734,514,154,30,actions,'downloadAll:','arrow.down.circle.fill');state.downloadAllBtn.enabled=false;c.addSubview(state.downloadAllBtn)

  // Scrollable queue
  state.queueScroll=$.NSScrollView.alloc.initWithFrame($.NSMakeRect(32,184,856,320));state.queueScroll.hasVerticalScroller=true;state.queueScroll.autohidesScrollers=true;state.queueScroll.borderType=$.NSNoBorder;state.queueScroll.drawsBackground=false
  state.queueDoc=$.NSView.alloc.initWithFrame($.NSMakeRect(0,0,824,326));state.queueScroll.documentView=state.queueDoc;c.addSubview(state.queueScroll)

  // Settings card
  var settings=card(32,72,856,92,18);c.addSubview(settings)
  settings.addSubview(label('格式',18,54,40,20,10,$.NSFontWeightSemibold,$.NSColor.secondaryLabelColor))
  state.quality=popup(['最佳 MP4','最高 4K','最高 1080p','最高 720p','仅音频'],58,45,180,30);state.quality.target=actions;state.quality.action='qualityChanged:';settings.addSubview(state.quality)
  settings.addSubview(label('Cookies',258,54,54,20,10,$.NSFontWeightSemibold,$.NSColor.secondaryLabelColor))
  state.cookies=popup(['不使用','Safari','Chrome','Firefox'],314,45,138,30);settings.addSubview(state.cookies)
  settings.addSubview(label('保存到',474,54,48,20,10,$.NSFontWeightSemibold,$.NSColor.secondaryLabelColor))
  state.pathLabel=label(state.outputDir,524,53,236,20,10,$.NSFontWeightRegular,$.NSColor.secondaryLabelColor);state.pathLabel.lineBreakMode=$.NSLineBreakByTruncatingMiddle;settings.addSubview(state.pathLabel)
  var chooseBtn=button('更改',766,44,72,30,actions,'chooseFolder:','folder.badge.gearshape');settings.addSubview(chooseBtn)
  var privacy=label('不保存下载历史  ·  无后台服务  ·  无 LaunchAgent  ·  运行缓存仅在系统临时目录  ·  删除 App 即卸载',18,13,820,20,10,$.NSFontWeightRegular,$.NSColor.tertiaryLabelColor);settings.addSubview(privacy)

  c.addSubview(label('YTDock 1.0  ·  Free Distribution Build',32,34,330,22,10,$.NSFontWeightSemibold,$.NSColor.tertiaryLabelColor))
  var note=label('仅下载你有权保存的内容',636,34,252,22,10,$.NSFontWeightRegular,$.NSColor.tertiaryLabelColor);note.alignment=$.NSTextAlignmentRight;c.addSubview(note)

  renderQueue(actions);state.timer=$.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(0.30,actions,'tick:',null,true)
  win.makeKeyAndOrderFront(null);app.activateIgnoringOtherApps(true);app.run
}
