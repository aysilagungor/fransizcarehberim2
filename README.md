# Fransızca Rehberim — GitHub için klasörsüz, görselleri düzeltilmiş sürüm

Bu sürüm eski V5 projesinin tasarımını, HTML sayfalarını, oyunlarını, `cloud.js` ve `config.js` dosyalarını korur. Görseller ana dizine taşındı ve `app.js` / `style.css` referansları düzeltildi.

## GitHub

ZIP dosyasını bilgisayarında aç. İçindeki **dosyaları** GitHub deposunun **ana dizinine** güncelle; ZIP dosyasını değil. `index.html`, `app.js`, `style.css`, dört JPG ve diğer dosyalar aynı seviyede bulunmalı. Bunları eski dosyaların üstüne yazacak şekilde GitHub Desktop veya VS Code üzerinden commit ve push ile gönder.

Önemli: Yalnızca görsel isimlerini değiştirmek yeterli değil; **güncel `style.css` ve `app.js` dosyaları da** GitHub'a gönderilmeli.

## Cloudflare Workers

Build command: boş bırak.

Deploy command: `npx wrangler deploy --assets . --compatibility-date 2026-11-01`

Root directory: `/`.

Cloudflare'ın en son GitHub commit'ini dağıttığından emin ol. Önce `.workers.dev` test adresini kullan; mevcut alan adını değiştirme.

## Basit kontrol

`/gorsel-kontrol.html` sayfası dört resmin yüklenip yüklenmediğini tek ekranda gösterir. Bu kontrol sayfası halka açık site navigasyonuna eklenmemiştir; sorun giderme amaçlıdır.

## Supabase

`config.js` yüklenen orijinal ZIP'teki gibi korunmuştur. Bu dosyada Supabase URL / publishable key boşsa bulut hesabı çalışmaz; buna rağmen ders ve oyunların tarayıcıdaki demo işlevleri devam eder. Gizli `service_role` anahtarı asla JavaScript'e koyma. SQL şeması `schema.sql` olarak ana dizindedir; **bu dosyayı herkese açık depoya yüklemek zorunda değilsin** (veritabanına SQL Editor üzerinden uygulanır). Gerçek kullanım için kimlik doğrulama ve RLS kontrolleri ayrıca yapılmalıdır.
