window.I18N={
tr:{
 selectedLocation:'Seçili konum', todaySunTimes:'Bugün',
 title:'NetRelayMP', sub:'Enerji ve röle yönetimi', brandSub:'Standalone · 8088',
 dash:'Panel', wifi:'Wi‑Fi', network:'Ağ', schedule:'Zamanlama',
 ping:'Ping', backup:'Yedek', settings:'Ayarlar', setup:'Kurulum', api:'API',
 login:'Giriş', user:'Kullanıcı adı', pass:'Parola', loginBtn:'Giriş yap', logout:'Çıkış',
 allOn:'Tümünü aç', allOff:'Tümünü kapat', allCycle:'Yeniden başlat',
 confirmAllOn:'Tüm prizler açılacak. Onaylıyor musunuz?',
 confirmAllOff:'Tüm prizler kapatılacak. Onaylıyor musunuz?',
 confirmAllCycle:'Tüm prizlerin elektriği 10 saniye kesilip yeniden açılacak. Onaylıyor musunuz?',
 apiKey:'API anahtarı', csv:'CSV', outlet:'Priz', on:'Aç', off:'Kapat',
 pulse:'Pulse (eski konum)', cycle:'10 sn cycle',
 needKey:'Yazma için giriş veya API anahtarı gerekli.',
 connecting:'Bağlanıyor…', open:'Açık', closed:'Kapalı',
 watt:'Güç', energy:'Enerji', lang:'Dil', menu:'Menü', uptime:'Açık süre',
 panel:'Panel', save:'Kaydet', refresh:'Yenile', connect:'Bağlan', scan:'Ağları tara',
 show:'Göster', hide:'Gizle', back:'Geri', next:'Devam', skip:'Atla', add:'Ekle',
 del:'Sil', edit:'Düzenle', update:'Güncelle', cancel:'İptal', updated:'Güncellendi', confirmDeleteRule:'Bu zamanlama kuralı silinsin mi?', reboot:'Yeniden başlat', factory:'Fabrika ayarlarına dön',
 saved:'Kaydedildi', error:'Hata', required:'gerekli', invalid:'geçersiz',
 wifiTitle:'Wi‑Fi', wifiSub:'Ağ tara · bağlan',
 netTitle:'Ağ', netSub:'IP · subnet · gateway · DNS',
 schedTitle:'Zamanlama', schedSub:'Otomatik aç/kapa · pulse · güneş',
 pingTitle:'Ping izleme', pingSub:'Her priz için ayrı kural',
 bakTitle:'Yedek & Saha', bakSub:'Filo kopyalama / sağlık',
 setTitle:'Ayarlar', setSub:'Cihaz, MQTT, saat, firmware',
 setupTitle:'Kurulum', setupSub:'İlk kurulum sihirbazı',
 setupSubWifiOnly:'Wi‑Fi’ye bağlanın · IP otomatik (DHCP)',
 apiTitle:'REST / MQTT API', apiSub:'REST aç/kapa · entegrasyon referansı',
 apiRest:'REST API', apiOn:'REST API açık', apiOff:'REST API kapalı',
 apiToggleNote:'Kapalıyken token ile dışarıdan okuma/yazma durur. Panele giriş ve MQTT çalışmaya devam eder.',
 apiSaved:'REST API ayarı kaydedildi',
 ssid:'SSID', security:'Güvenlik', wifiPass:'Wi‑Fi parolası',
 wifiMode:'İstemci modu', modeStation:'Station', modeWds:'Station WDS',
 wpa:'WPA / WPA2', openNet:'Açık (parolasız)', foundNets:'Bulunan ağlar',
 pressScan:'Tarama için butona basın', link:'Bağlantı', recoveryIp:'Kurtarma IP', recoveryOn:'Açık', recoveryOff:'Kapalı (STA bağlı)',
 notLinked:'Bağlı değil', addrMode:'Adresleme', mode:'Mod',
 dhcp:'DHCP (otomatik)', staticIp:'Statik IP',
 ipAddr:'IP adresi', subnet:'Subnet mask', gateway:'Ağ geçidi', dns1:'DNS 1', dns2:'DNS 2',
 liveIp:'Anlık IP',
 kind:'Tür', kindClock:'Saat', kindPulse:'Pulse', kindRise:'Gün doğumu', kindSet:'Gün batımı',
 time:'Saat', port:'Priz', state:'Durum', days:'Günler', everyDay:'Her gün', weekdays:'Hafta içi',
 pulseSec:'Pulse süresi (sn)', sunOffset:'Güneş ofseti (dk)', noRules:'Henüz kural yok — yukarıdan ekleyin',
 pulseNeedDur:'Pulse için süre (sn) girin', added:'Eklendi', minAbbrev:'dk',
 ruleOn:'Kural açık', ruleOff:'Kural kapalı', target:'Hedef (IP / domain)',
 interval:'Aralık (sn)', failCount:'Ardışık fail', onUnreach:'Ulaşılamazsa',
 restoreSec:'Eski haline (sn)', cooldown:'Cooldown (sn)', pingTest:'Ping test',
 saveRule:'Bu kuralı kaydet', saveAll:'Tümünü kaydet', service:'Servis',
 toggle:'Tersine çevir', running:'Çalışıyor', stopped:'Durdu',
 waiting:'Bekleniyor', reachable:'Ulaşılıyor', unreachable:'Ulaşılamıyor', busy:'İşlemde…',
 pingNote:'Kilitli priz atlanır. Cooldown peş peşe tetiklemeyi engeller.',
 pingFlow:'3 bağımsız kural: her röle kendi hedefini izler. Hedef düşerse o priz açılır / kapanır / tersine çevrilir, sonra eski haline döner.',
 counters:'Sayaç', lastOk:'Son OK', lastFail:'Fail',
 saving:'Kaydediliyor…', savedRules:'3 kural kaydedildi',
 savingPort:'Priz {n} kaydediliyor…', savedPort:'Priz {n} kaydedildi',
 needTarget:'Priz {n}: hedef yazın', pingingPort:'Priz {n} ping…',
 portReach:'Priz {n}: ulaşıyor ({h})', portUnreach:'Priz {n}: ulaşılamıyor ({h})',
 statusFail:'Durum okunamadı',
 health:'Sağlık', bakExport:'Ayar yedeği indir', bakImport:'Yedeği geri yükle',
 bakSecrets:'Wi‑Fi/MQTT parolası ve API token dahil', bakDl:'JSON indir', bakImp:'İçe aktar',
 bakHint:'Aynı Wi‑Fi/MQTT profilini diğer cihazlara basmak için bir master yedeği kullanın.',
 bakField:'MQTT / HA saha kontrol',
 bakDocs:'TR: docs/SAHA-TR.md · EN: docs/SAHA-EN.md',
 deviceName:'Cihaz adı', nameLabel:'Ad (MQTT / panel)', macLabel:'MAC adresi', ledOn:'Durum LED’i açık', saveLed:'LED ayarını kaydet', ledHint:'Bağlıyken mavi, kurtarma modunda sarı; kapatılırsa LED tamamen söner.', ledSaved:'LED ayarı kaydedildi', oldPass:'Eski', newPass:'Yeni',
 locationTime:'Konum & Saat',
 locDefault:'Varsayılan konum: Çorlu / Tekirdağ (41.1592, 27.8000) — gün doğumu/batımı için.',
 latitude:'Enlem', longitude:'Boylam', utcOffset:'UTC ofset', ntpServer:'NTP sunucu (IP veya hostname)',
 tryNtp:'NTP dene', setBrowserTime:'Tarayıcı saatini yaz', tryingNtp:'NTP deneniyor…',
 mqttHa:'MQTT / Home Assistant', mqttOn:'MQTT açık', mqttSave:'MQTT kaydet',
 mqttSaving:'Lütfen bekleyin, kaydediliyor…', mqttSaved:'MQTT ayarları başarıyla kaydedildi', mqttSaveFailed:'MQTT ayarları kaydedilemedi',
 mqttConnecting:'Ayarlar kaydedildi, MQTT sunucusuna bağlanılıyor…', mqttConnected:'MQTT sunucusuna bağlandı', mqttConnectFailed:'MQTT sunucusuna bağlanamadı',
 mqttProtocol:'MQTT protokolü sunucu tarafından reddedildi', mqttClientId:'İstemci kimliği reddedildi', mqttUnavailable:'Sunucu kullanılamıyor', mqttCredentials:'Kullanıcı adı veya parola hatalı', mqttUnauthorized:'Bağlantı yetkisi reddedildi', mqttConnectionClosed:'Bağlantı sunucu tarafından kapatıldı', mqttConnectTimeout:'Bağlantı zaman aşımı; broker adresi, port ve ağ erişimini kontrol edin',
 broker:'Broker', mqttUser:'Kullanıcı', mqttPassPh:'(boş=değişmez)', prefix:'Prefix',
 mqttHostPh:'mqtt.example.com', mqttPortPh:'1883', mqttUserPh:'mqtt',
 mqttPrefixPh:'mpower/mltek', mqttIntervalPh:'15',
 mqttCustom:'Custom', mqttCustomPh:'site=warehouse',
 mqttCustomHint:'Broker’a {prefix}/{MAC}/custom ve state JSON içinde custom olarak gider.',
 intervalSec:'Aralık (sn)', haDiscovery:'HA discovery',
 fwUpdate:'Firmware güncelle (overlay tar)', uploadInstall:'Yükle & kur', orUrl:'veya URL',
 fwUrlPh:'https://github.com/mlteknoloji/ubnt_mPOWER/blob/main/standalone-firmware/dist/mpower-overlay-latest.tar',
 fwUrlHint:'Boş bırakınca GitHub latest tar kullanılır. /blob/ sayfası tar değildir; tarayıcı raw dosyayı indirir.',
 installUrl:'URL ile kur', uploading:'Yükleniyor…', fwInstalling:'Kuruluyor…', fwRestarting:'Servis yeniden başlıyor, sonuç bekleniyor…', fwSuccess:'Firmware güncellemesi başarılı', fwFailed:'Firmware güncellemesi başarısız', fwTimeout:'Sonuç alınamadı; cihaz durumunu kontrol edin',
 apiToken:'API token', browserToken:'Tarayıcı token',
 apiTokNote:'Varsayılan (ilk kurulum / fabrika):',
 apiTokDevice:'Cihaz:',
 device:'Cihaz',
 deviceNote:'Yeniden başlat: ayarlar korunur.\nNetRelayMP fabrika yalnız bu sayfadaki düğmeden yapılır; ayarlar sıfırlanır, overlay kalır.\nDikkat: Fiziksel düğmeye uzun basmak stock fabrika sıfırlamasını başlatır ve yazılımı siler.\nFiziksel düğme: yalnız 2 sn = yeniden başlat; daha uzun basmayın.',
 rebooting:'Yeniden başlatılıyor…', resetting:'Sıfırlanıyor…', deviceRestarting:'Cihaz yeniden başlıyor…',
 confirmReboot:'Cihazı yeniden başlatmak istiyor musunuz?',
 confirmFactory:'NetRelayMP fabrika ayarları? Wi‑Fi, MQTT, ağ, zamanlama ve parola sıfırlanır; overlay kalır.',
 confirmFactory2:'Son onay: soft fabrika + yeniden başlatma (yazılım silinmez)',
 clockFix:'Wi‑Fi+NTP veya “Cihaz saatini düzelt”',
 schedNote:'Saat için Ayarlar’da NTP/konum gerekir. Güneş kuralları lat/lon kullanır.',
 stepNow:'şimdi', stepHint:'Adımlara dokunarak istediğiniz bölüme geçebilirsiniz',
 finish:'Bitir', password:'Parola',
 scanning:'Ağlar taranıyor…', netsFound:'{n} ağ bulundu', noNets:'Ağ yok — SSID yazın',
 listed:'{n} ağ listelendi', scanEmpty:'Tarama boş. SSID’yi elle girin.',
 scanFail:'Tarama başarısız', statusUpdated:'Durum güncellendi',
 ssidNeed:'SSID gerekli', passNeed:'Wi‑Fi parolası gerekli',
 wpaLen:'WPA parolası 8–63 karakter olmalı',
 wifiStarted:'Bağlantı başlatıldı. Birkaç saniye sonra kurtarma AP kapanabilir — LAN IP veya NRfinder / http://192.168.2.20:8088 ile devam edin.',
 wifiStartedDhcp:'Wi‑Fi bağlantısı başlatıldı; IP için DHCP otomatik seçildi. Birkaç saniye bekleyin.',
 wifiStartedOk:'Bağlantı komutu alındı. AP kapanırsa NRfinder veya yeni Wi‑Fi IP ile panele girin.',
 wifiFetchHint:'İstek kesildi (AP kapanmış olabilir). Ayar kaydedilmiş olabilir — NRfinder veya LAN IP ile deneyin.',
 wifiNoIp:'Wi‑Fi bağlı ama IP yok — DHCP yenileniyor / Ağ sayfasından DHCP kaydedin.',
 wifiWait:'Bağlantı deneniyor… (SSID / parola kontrol ediliyor)',
 wifiWaitTry:'Bağlantı deneniyor… ({n}/2)',
 wifiOk:'Wi‑Fi bağlandı',
 wifiOkIp:'Wi‑Fi bağlandı · IP {ip}',
 wifiFailAssoc:'Wi‑Fi bağlanamadı: ağ bulunamadı veya parola hatalı (SSID: {ssid}). Kurtarma AP açık — tekrar deneyin.',
 wifiFailGaveUp:'Wi‑Fi bağlanamadı. Kurtarma AP açık; cihaz 60 sn’de bir yeniden deneyecek. SSID/parolayı kontrol edin.',
 wifiFailDhcp:'Wi‑Fi bağlandı ama IP alınamadı (DHCP). Kurtarma AP açık — Ağ sayfasından deneyin veya tekrar bağlanın.',
 wifiFailWpa:'Wi‑Fi başlatılamadı (WPA). Parolayı kontrol edip tekrar deneyin.',
 wifiFailBadPw:'WPA parolası geçersiz (8–63 karakter).',
 wifiFailGeneric:'Wi‑Fi bağlanamadı ({reason}). Kurtarma AP açık — tekrar deneyin.',
 wifiFailTimeout:'Wi‑Fi bağlanamadı. Telefonu kurtarma ağına (mFi…) alın; hata orada görünür.',
 wifiMaybeOk:'Kurtarma AP kapandı — Wi‑Fi muhtemelen bağlandı. NRfinder veya LAN IP ile panele girin.',
 wifiErr:'Bağlantı hatası', tokenNeed:'token gerekli',
 netSaved:'Ağ ayarları kaydedildi', saveErr:'Kayıt hatası',
 pwUpdated:'Parola güncellendi', pwFail:'Parola değiştirilemedi',
 gwSameNet:'Gateway, IP ile aynı ağda olmalı',
 netSavedRec:'Kaydedildi · kurtarma (AP kapalıyken LAN IP): http://{ip}:8088',
 seconds:'saniye', pulseTarget:'hedef 0/1 (boş=tersine)',
 deviceClock:'Cihaz saati', firmware:'Firmware', overlay:'Overlay', wifiIp:'Wi‑Fi / IP',
 fixTime:'Cihaz saatini düzelt',
 ntpNoNet:'NTP çalışmıyor: cihazın interneti yok (Wi‑Fi bağlı değil / varsayılan ağ geçidi yok). Önce Wi‑Fi bağlayın veya “Tarayıcı saatini yaz” kullanın.',
 ntpNoDns:'NTP: DNS yok. NTP alanına doğrudan IP yazın (ör. 216.239.35.0) veya tarayıcı saatini yazın.',
 ntpFail:'NTP başarısız. Log: ',
 clockOk:'Saat senkron (NTP veya manuel).',
 netRouteYes:' · İnternet rotası: var', netRouteNo:' · İnternet rotası: yok',
 deviceNow:'Cihaz: ', wifiNote:'WPA parolası 8–63 karakter. Bağlanınca kurtarma AP (mFi…) kapanır; bağlantı düşünce yeniden açılır.',
 staticNeed:'Statik modda IP, maske ve gateway gerekli',
 pwMin:'Yeni parola en az 4 karakter olmalı', pwMismatch:'Parolalar eşleşmiyor',
 finishing:'Tamamlanıyor…', setupDone:'Kurulum tamam',
 wifiLead:'Kurtarma AP ile bağlanıp ağı seçin. Station modunda IP modem/router DHCP’sinden alınır. STA bağlanınca AP kapanır; kopunca http://192.168.2.20:8088 tekrar gelir.',
 setupLead:'Şu an cihazın kurtarma AP’sine (mFi…) bağlısınız. Ev/iş ağını tarayıp Bağlan deyin — cihaz Station modunda IP’yi modem/router DHCP’sinden alır. Bağlanınca AP kapanır; kopunca 192.168.2.20 yeniden açılır.',
 upD:'g', upH:'sa', upM:'dk', upS:'sn'
},
en:{
 selectedLocation:'Selected location', todaySunTimes:'Today',
 title:'NetRelayMP', sub:'Energy and relay control', brandSub:'Standalone · 8088',
 dash:'Dashboard', wifi:'Wi‑Fi', network:'Network', schedule:'Schedule',
 ping:'Ping', backup:'Backup', settings:'Settings', setup:'Setup', api:'API',
 login:'Sign in', user:'Username', pass:'Password', loginBtn:'Sign in', logout:'Log out',
 allOn:'All on', allOff:'All off', allCycle:'Power cycle',
 confirmAllOn:'All outlets will be turned on. Continue?',
 confirmAllOff:'All outlets will be turned off. Continue?',
 confirmAllCycle:'Power to all outlets will be cut for 10 seconds and then restored. Continue?',
 apiKey:'API token', csv:'CSV', outlet:'Outlet', on:'On', off:'Off',
 pulse:'Pulse (restore)', cycle:'10s cycle',
 needKey:'Sign in or API token required for writes.',
 connecting:'Connecting…', open:'On', closed:'Off',
 watt:'Power', energy:'Energy', lang:'Language', menu:'Menu', uptime:'Uptime',
 panel:'Dashboard', save:'Save', refresh:'Refresh', connect:'Connect', scan:'Scan networks',
 show:'Show', hide:'Hide', back:'Back', next:'Continue', skip:'Skip', add:'Add',
 del:'Delete', edit:'Edit', update:'Update', cancel:'Cancel', updated:'Updated', confirmDeleteRule:'Delete this schedule rule?', reboot:'Reboot', factory:'Factory reset',
 saved:'Saved', error:'Error', required:'required', invalid:'invalid',
 wifiTitle:'Wi‑Fi', wifiSub:'Scan · connect',
 netTitle:'Network', netSub:'IP · subnet · gateway · DNS',
 schedTitle:'Schedule', schedSub:'Auto on/off · pulse · sun',
 pingTitle:'Ping watch', pingSub:'Separate rule per outlet',
 bakTitle:'Backup & field', bakSub:'Fleet clone / health',
 setTitle:'Settings', setSub:'Device, MQTT, clock, firmware',
 setupTitle:'Setup', setupSub:'First-run wizard',
 setupSubWifiOnly:'Connect to Wi‑Fi · IP automatic (DHCP)',
 apiTitle:'REST / MQTT API', apiSub:'REST on/off · integration reference',
 apiRest:'REST API', apiOn:'REST API on', apiOff:'REST API off',
 apiToggleNote:'When off, token read/write from outside is blocked. Signed-in panel and MQTT keep working.',
 apiSaved:'REST API setting saved',
 ssid:'SSID', security:'Security', wifiPass:'Wi‑Fi password',
 wifiMode:'Client mode', modeStation:'Station', modeWds:'Station WDS',
 wpa:'WPA / WPA2', openNet:'Open (no password)', foundNets:'Found networks',
 pressScan:'Press scan to list networks', link:'Link', recoveryIp:'Recovery IP', recoveryOn:'On', recoveryOff:'Off (STA linked)',
 notLinked:'Not linked', addrMode:'Addressing', mode:'Mode',
 dhcp:'DHCP (automatic)', staticIp:'Static IP',
 ipAddr:'IP address', subnet:'Subnet mask', gateway:'Gateway', dns1:'DNS 1', dns2:'DNS 2',
 liveIp:'Current IP',
 kind:'Type', kindClock:'Clock', kindPulse:'Pulse', kindRise:'Sunrise', kindSet:'Sunset',
 time:'Time', port:'Outlet', state:'State', days:'Days', everyDay:'Every day', weekdays:'Weekdays',
 pulseSec:'Pulse duration (s)', sunOffset:'Sun offset (min)', noRules:'No rules yet — add one above',
 pulseNeedDur:'Enter pulse duration (s)', added:'Added', minAbbrev:'min',
 ruleOn:'Rule on', ruleOff:'Rule off', target:'Target (IP / domain)',
 interval:'Interval (s)', failCount:'Fail count', onUnreach:'On unreachable',
 restoreSec:'Restore after (s)', cooldown:'Cooldown (s)', pingTest:'Ping test',
 saveRule:'Save this rule', saveAll:'Save all', service:'Service',
 toggle:'Toggle', running:'Running', stopped:'Stopped',
 waiting:'Waiting', reachable:'Reachable', unreachable:'Unreachable', busy:'Busy…',
 pingNote:'Locked outlets are skipped. Cooldown prevents back-to-back triggers.',
 pingFlow:'3 independent rules: each relay watches its own target. On failure that outlet turns on / off / toggles, then restores.',
 counters:'Count', lastOk:'Last OK', lastFail:'Fail',
 saving:'Saving…', savedRules:'3 rules saved',
 savingPort:'Saving outlet {n}…', savedPort:'Outlet {n} saved',
 needTarget:'Outlet {n}: enter a target', pingingPort:'Outlet {n} ping…',
 portReach:'Outlet {n}: reachable ({h})', portUnreach:'Outlet {n}: unreachable ({h})',
 statusFail:'Could not read status',
 health:'Health', bakExport:'Download settings backup', bakImport:'Restore backup',
 bakSecrets:'Include Wi‑Fi/MQTT passwords and API token', bakDl:'Download JSON', bakImp:'Import',
 bakHint:'Use one master backup to push the same Wi‑Fi/MQTT profile to other devices.',
 bakField:'MQTT / HA field check',
 bakDocs:'TR: docs/SAHA-TR.md · EN: docs/SAHA-EN.md',
 deviceName:'Device name', nameLabel:'Name (MQTT / panel)', macLabel:'MAC address', ledOn:'Status LED enabled', saveLed:'Save LED setting', ledHint:'Blue while connected, yellow in recovery mode; disabling turns the LED off.', ledSaved:'LED setting saved', oldPass:'Current', newPass:'New',
 locationTime:'Location & time',
 locDefault:'Default location: Çorlu / Tekirdağ (41.1592, 27.8000) — for sunrise/sunset.',
 latitude:'Latitude', longitude:'Longitude', utcOffset:'UTC offset', ntpServer:'NTP server (IP or hostname)',
 tryNtp:'Try NTP', setBrowserTime:'Write browser time', tryingNtp:'Trying NTP…',
 mqttHa:'MQTT / Home Assistant', mqttOn:'MQTT enabled', mqttSave:'Save MQTT',
 mqttSaving:'Please wait, saving…', mqttSaved:'MQTT settings saved successfully', mqttSaveFailed:'Could not save MQTT settings',
 mqttConnecting:'Settings saved; connecting to the MQTT server…', mqttConnected:'Connected to the MQTT server', mqttConnectFailed:'Could not connect to the MQTT server',
 mqttProtocol:'The server rejected the MQTT protocol', mqttClientId:'Client identifier rejected', mqttUnavailable:'Server unavailable', mqttCredentials:'Invalid username or password', mqttUnauthorized:'Connection not authorized', mqttConnectionClosed:'The server closed the connection', mqttConnectTimeout:'Connection timed out; check the broker address, port, and network access',
 broker:'Broker', mqttUser:'User', mqttPassPh:'(empty=unchanged)', prefix:'Prefix',
 mqttHostPh:'mqtt.example.com', mqttPortPh:'1883', mqttUserPh:'mqtt',
 mqttPrefixPh:'mpower/mltek', mqttIntervalPh:'15',
 mqttCustom:'Custom', mqttCustomPh:'site=warehouse',
 mqttCustomHint:'Sent to the broker as {prefix}/{MAC}/custom and inside state JSON as custom.',
 intervalSec:'Interval (s)', haDiscovery:'HA discovery',
 fwUpdate:'Firmware update (overlay tar)', uploadInstall:'Upload & install', orUrl:'or URL',
 fwUrlPh:'https://github.com/mlteknoloji/ubnt_mPOWER/blob/main/standalone-firmware/dist/mpower-overlay-latest.tar',
 fwUrlHint:'Empty uses the GitHub latest tar. A /blob/ page is not the file; the browser fetches the raw tar.',
 installUrl:'Install from URL', uploading:'Uploading…', fwInstalling:'Installing…', fwRestarting:'Service is restarting; waiting for result…', fwSuccess:'Firmware update successful', fwFailed:'Firmware update failed', fwTimeout:'No result received; check device status',
 apiToken:'API token', browserToken:'Browser token',
 apiTokNote:'Default (first install / factory):',
 apiTokDevice:'Device:',
 device:'Device',
 deviceNote:'Reboot keeps settings.\nNetRelayMP factory reset is available only from this page; settings are cleared and the overlay stays.\nWarning: a long hardware-button hold triggers stock reset and erases the overlay.\nHardware button: about 2 s = reboot only; do not hold longer.',
 rebooting:'Rebooting…', resetting:'Resetting…', deviceRestarting:'Device is restarting…',
 confirmReboot:'Reboot the device?',
 confirmFactory:'NetRelayMP factory reset? Clears Wi‑Fi, MQTT, network, schedules and password; overlay stays.',
 confirmFactory2:'Final confirm: soft factory + reboot (software is kept)',
 clockFix:'Wi‑Fi+NTP or “Fix device clock”',
 schedNote:'Clock needs NTP/location in Settings. Sun rules use lat/lon.',
 stepNow:'now', stepHint:'Tap steps to jump between sections',
 finish:'Finish', password:'Password',
 scanning:'Scanning networks…', netsFound:'{n} networks found', noNets:'No networks — type SSID',
 listed:'{n} networks listed', scanEmpty:'Scan empty. Enter SSID manually.',
 scanFail:'Scan failed', statusUpdated:'Status updated',
 ssidNeed:'SSID required', passNeed:'Wi‑Fi password required',
 wpaLen:'WPA password must be 8–63 characters',
 wifiStarted:'Connecting started. Recovery AP may turn off in a few seconds — continue via LAN IP, NRfinder, or http://192.168.2.20:8088.',
 wifiStartedDhcp:'Wi‑Fi connect started; DHCP selected automatically for IP. Wait a few seconds.',
 wifiStartedOk:'Connect command accepted. If the AP drops, open the panel via NRfinder or the new Wi‑Fi IP.',
 wifiFetchHint:'Request interrupted (AP may have closed). Settings may still be saved — try NRfinder or LAN IP.',
 wifiNoIp:'Wi‑Fi linked but no IP — renewing DHCP / save DHCP on the Network page.',
 wifiWait:'Connecting… (checking SSID / password)',
 wifiWaitTry:'Connecting… ({n}/2)',
 wifiOk:'Wi‑Fi connected',
 wifiOkIp:'Wi‑Fi connected · IP {ip}',
 wifiFailAssoc:'Wi‑Fi could not connect: network not found or wrong password (SSID: {ssid}). Recovery AP is on — try again.',
 wifiFailGaveUp:'Wi‑Fi could not connect. Recovery AP is on; the device retries every 60s. Check SSID/password.',
 wifiFailDhcp:'Wi‑Fi linked but no IP (DHCP). Recovery AP is on — retry from Network or Setup.',
 wifiFailWpa:'Could not start Wi‑Fi (WPA). Check the password and retry.',
 wifiFailBadPw:'Invalid WPA password (8–63 characters).',
 wifiFailGeneric:'Wi‑Fi could not connect ({reason}). Recovery AP is on — try again.',
 wifiFailTimeout:'Wi‑Fi could not connect. Rejoin the recovery network (mFi…) to see the error.',
 wifiMaybeOk:'Recovery AP closed — Wi‑Fi likely connected. Open the panel via NRfinder or LAN IP.',
 wifiErr:'Connection error', tokenNeed:'token required',
 netSaved:'Network settings saved', saveErr:'Save failed',
 pwUpdated:'Password updated', pwFail:'Could not change password',
 gwSameNet:'Gateway must be on the same network as the IP',
 netSavedRec:'Saved · recovery (when AP off use LAN IP): http://{ip}:8088',
 seconds:'seconds', pulseTarget:'target 0/1 (empty=flip)',
 deviceClock:'Device clock', firmware:'Firmware', overlay:'Overlay', wifiIp:'Wi‑Fi / IP',
 fixTime:'Fix device clock',
 ntpNoNet:'NTP failed: no internet (Wi‑Fi down / no default gateway). Connect Wi‑Fi first or use “Write browser time”.',
 ntpNoDns:'NTP: no DNS. Put an IP in the NTP field (e.g. 216.239.35.0) or write browser time.',
 ntpFail:'NTP failed. Log: ',
 clockOk:'Clock synced (NTP or manual).',
 netRouteYes:' · Internet route: yes', netRouteNo:' · Internet route: no',
 deviceNow:'Device: ', wifiNote:'WPA password 8–63 chars. Recovery AP (mFi…) turns off when linked; comes back if STA drops.',
 staticNeed:'Static mode needs IP, mask and gateway',
 pwMin:'New password must be at least 4 characters', pwMismatch:'Passwords do not match',
 finishing:'Finishing…', setupDone:'Setup complete',
 wifiLead:'Join via recovery AP and pick your LAN. Station mode gets its address from the modem/router DHCP server. AP turns off when linked; if link drops, http://192.168.2.20:8088 returns.',
 setupLead:'You are on the device recovery AP (mFi…). Scan your LAN and tap Connect — Station mode gets its address from the modem/router DHCP server. AP turns off when linked; 192.168.2.20 returns if the link drops.',
 upD:'d', upH:'h', upM:'m', upS:'s'
}
};

(function ensureFavicon(){
  if(typeof document==='undefined'||!document.head) return;
  if(document.querySelector('link[rel="icon"]')) return;
  const svg=document.createElement('link');
  svg.rel='icon'; svg.type='image/svg+xml'; svg.href='favicon.svg';
  document.head.appendChild(svg);
  const png=document.createElement('link');
  png.rel='icon'; png.type='image/png'; png.sizes='32x32'; png.href='favicon.png';
  document.head.appendChild(png);
  const apple=document.createElement('link');
  apple.rel='apple-touch-icon'; apple.href='favicon.png';
  document.head.appendChild(apple);
})();

window.lang=()=>localStorage.getItem('mpower-lang')||'tr';
window.t=(k,vars)=>{
  const L=lang();
  let s=(I18N[L]||I18N.tr)[k]||(I18N.tr[k])||k;
  if(vars&&typeof vars==='object'){
    Object.keys(vars).forEach(v=>{s=s.replace(new RegExp('\\{'+v+'\\}','g'),vars[v])});
  }
  return s;
};
window.setLang=(l)=>{localStorage.setItem('mpower-lang',l);location.reload()};

window.applyI18n=(root)=>{
  const el=root||document;
  el.querySelectorAll('[data-i18n]').forEach(n=>{
    const k=n.getAttribute('data-i18n');
    if(!k) return;
    const val=t(k);
    if(n.tagName==='INPUT'||n.tagName==='TEXTAREA'){
      if(n.hasAttribute('data-i18n-placeholder')) n.placeholder=val;
      else n.value=val;
    }else if(n.tagName==='OPTION') n.textContent=val;
    else n.textContent=val;
  });
  el.querySelectorAll('[data-i18n-html]').forEach(n=>{
    const k=n.getAttribute('data-i18n-html');
    if(k) n.innerHTML=t(k).replace(/\n/g,'<br>');
  });
  el.querySelectorAll('[data-i18n-placeholder]').forEach(n=>{
    n.placeholder=t(n.getAttribute('data-i18n-placeholder'));
  });
  el.querySelectorAll('[data-i18n-title]').forEach(n=>{
    n.title=t(n.getAttribute('data-i18n-title'));
  });
  const pageTitle=document.querySelector('[data-page-title]');
  if(pageTitle){
    const k=pageTitle.getAttribute('data-page-title');
    if(k) document.title=t(k)+' · NetRelayMP';
  }
  const html=document.documentElement;
  if(html) html.lang=lang();
};

window.MPNav={
  items:[
    {href:'/', key:'dash', match:['/', '/index.html']},
    {href:'wifi.html', key:'wifi'},
    {href:'network.html', key:'network'},
    {href:'schedule.html', key:'schedule'},
    {href:'ping.html', key:'ping'},
    {href:'backup.html', key:'backup'},
    {href:'settings.html', key:'settings'},
    {href:'setup.html', key:'setup'},
    {href:'api.html', key:'api'}
  ],
  mount(active){
    const path=location.pathname.replace(/\\/g,'/');
    const file=(path.split('/').pop()||'/');
    const app=document.getElementById('appShell');
    if(!app) return;
    const prevSide=document.getElementById('sidebar');
    if(prevSide) prevSide.remove();
    const prevBack=document.getElementById('navBackdrop');
    if(prevBack) prevBack.remove();
    const L=lang();
    const side=document.createElement('aside');
    side.className='sidebar';
    side.id='sidebar';
    side.innerHTML=`
      <a class="brand brand-home" href="/" title="NetRelayMP">
        <div class="brand-badge">NR</div>
        <div><h1>NetRelayMP</h1><p>${t('brandSub')}</p></div>
      </a>
      <nav class="side-nav" id="sideNav"></nav>
      <div class="side-foot">
        <label class="tog lang-tog" title="TR / EN" style="margin-bottom:8px">
          <span class="tog-text lang-tr">TR</span>
          <input type="checkbox" id="sideLang" aria-label="Language"${L==='en'?' checked':''}>
          <span class="tog-track"></span>
          <span class="tog-text lang-en">EN</span>
        </label>
        Ubiquiti mPower overlay
      </div>`;
    const home=side.querySelector('.brand-home');
    if(home) home.onclick=()=>document.body.classList.remove('nav-open');
    const nav=side.querySelector('#sideNav');
    this.items.forEach(it=>{
      const a=document.createElement('a');
      a.href=it.href;
      const isActive = active ? active===it.key : (it.match ? it.match.includes(file)||(file===''&&it.key==='dash') : file===it.href);
      if(isActive) a.classList.add('active');
      a.innerHTML=`<span class="ico">▸</span><span>${t(it.key)}</span>`;
      a.onclick=()=>document.body.classList.remove('nav-open');
      nav.appendChild(a);
    });
    const sideLang=side.querySelector('#sideLang');
    if(sideLang) sideLang.onchange=()=>setLang(sideLang.checked?'en':'tr');
    const backdrop=document.createElement('div');
    backdrop.className='backdrop'; backdrop.id='navBackdrop';
    backdrop.onclick=()=>document.body.classList.remove('nav-open');
    app.prepend(side);
    document.body.appendChild(backdrop);
    const btn=document.getElementById('menuBtn');
    if(btn){
      btn.setAttribute('aria-label',t('menu'));
      btn.onclick=()=>{
        document.body.classList.toggle('nav-open');
        side.classList.toggle('open');
        backdrop.classList.toggle('show');
      };
    }
    const obs=new MutationObserver(()=>{
      const open=document.body.classList.contains('nav-open');
      side.classList.toggle('open',open);
      backdrop.classList.toggle('show',open);
    });
    obs.observe(document.body,{attributes:true,attributeFilter:['class']});
    applyI18n(document);
  }
};

window.MPApi={
  DEFAULT_TOKEN:'6d6c74656b6e657472656c61796d70316d6c74656b6e657472656c61796d7031',
  token(){
    let tok=localStorage.getItem('mpower-api-token')||'';
    if(!tok){
      tok=this.DEFAULT_TOKEN;
      localStorage.setItem('mpower-api-token',tok);
    }
    return tok;
  },
  setToken(){
    let x=prompt(t('apiKey')+':',this.token()||this.DEFAULT_TOKEN);
    if(x===null)return;
    x=x.trim();
    if(x) localStorage.setItem('mpower-api-token',x);
    else localStorage.removeItem('mpower-api-token');
  },
  async req(u,write=false){
    if(write && this.token()) u+=(u.includes('?')?'&':'?')+'token='+encodeURIComponent(this.token());
    let r=await fetch(u,{method:write?'POST':'GET',credentials:'same-origin'});
    let x=await r.json().catch(()=>({}));
    if(r.status===401 && write){
      this.setToken();
      if(!this.token()) throw Error(t('needKey'));
      u=u.replace(/([?&])token=[^&]*/,'$1token='+encodeURIComponent(this.token()));
      if(!u.includes('token=')) u+=(u.includes('?')?'&':'?')+'token='+encodeURIComponent(this.token());
      r=await fetch(u,{method:'POST',credentials:'same-origin'});
      x=await r.json().catch(()=>({}));
    }
    if(!r.ok || x.ok===false) throw Error(x.error||t('error'));
    return x;
  }
};
