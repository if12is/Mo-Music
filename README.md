<div align="center">

<img src="icon.png" width="120" height="120" alt="Mo Music" style="border-radius:28px"/>

<h1>Mo Music</h1>

<p><strong>مشغّل موسيقى متعدد المنصات · العربية أولًا · RTL · Flutter</strong></p>
<p><strong>Offline-first cross-platform music player · Arabic-first · Flutter</strong></p>

<p>
  <a href="https://github.com/if12is/Mo-Music/releases/latest">
    <img src="https://img.shields.io/github/v/release/if12is/Mo-Music?style=for-the-badge&logo=github&logoColor=white&label=Release&color=3332CE" alt="Latest Release"/>
  </a>
  <a href="https://github.com/if12is/Mo-Music/releases/latest">
    <img src="https://img.shields.io/github/downloads/if12is/Mo-Music/total?style=for-the-badge&logo=github&logoColor=white&color=5A59E6" alt="Total Downloads"/>
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-GPLv3-blue?style=for-the-badge&logo=gnu&logoColor=white" alt="License"/>
  </a>
  <img src="https://img.shields.io/badge/Default%20language-Arabic-3332CE?style=for-the-badge" alt="Arabic"/>
</p>

<p>
  <a href="https://github.com/if12is/Mo-Music/releases/latest/download/MoMusic-android-universal.apk">
    <img src="https://img.shields.io/badge/Android-APK-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Download Android"/>
  </a>
  <a href="https://github.com/if12is/Mo-Music/releases/latest/download/MoMusic-windows-installer.exe">
    <img src="https://img.shields.io/badge/Windows-Installer-0078D4?style=for-the-badge&logo=windows&logoColor=white" alt="Download Windows"/>
  </a>
  <a href="https://github.com/if12is/Mo-Music/releases/latest/download/MoMusic-linux-x64.tar.gz">
    <img src="https://img.shields.io/badge/Linux-x64-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Download Linux"/>
  </a>
  <a href="https://github.com/if12is/Mo-Music/releases/latest/download/MoMusic-macos.zip">
    <img src="https://img.shields.io/badge/macOS-ZIP-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Download macOS"/>
  </a>
</p>

</div>

---

## ما هو مو ميوزك؟

**مو ميوزك** مشغّل موسيقى حديث يعمل أولًا بدون إنترنت، مع هوية بصرية جديدة ولغة عربية افتراضية واتجاه RTL.

Mo Music is a modern offline-first Flutter music player. Arabic is the default language, Cairo is the bilingual UI font, and in-app updates come from **this repository** (`if12is/Mo-Music`), not from the original upstream project.

## الهوية

- الاسم: **Mo Music** / **مو ميوزك**
- اللون: `#3332CE`
- الخط: **Cairo** (عربي + إنجليزي)
- التحديثات: `https://github.com/if12is/Mo-Music/releases`

## التحديثات والإصدارات

التطبيق يتحقق من الإصدارات عبر:

1. `UPDATE_CHECK_URL` إن وُجد في `.env`
2. `distribution/update-check.json` في هذا المستودع
3. GitHub Releases/Tags الخاصة بـ `if12is/Mo-Music`

لنشر إصدار جديد:

```bash
# 1) ارفع رقم الإصدار في pubspec.yaml مثل 2.5.0+74
# 2) ادفع التغييرات إلى dev
# 3) أنشئ tag وأصدر Release في GitHub
git tag v2.5.0
git push origin v2.5.0
```

إنشاء Release في GitHub يشغّل بناء المنصات ويرفع ملفات:

| المنصة | الملف |
|---|---|
| Android | `MoMusic-android-universal.apk` |
| Windows | `MoMusic-windows-installer.exe` |
| Linux | `MoMusic-linux-x64.tar.gz` |
| macOS | `MoMusic-macos.zip` |
| iOS | `MoMusic-ios-unsigned.ipa` |

يمكن أيضًا تشغيل workflow `Publish update manifest` لتحديث `distribution/update-check.json`.

## البناء من المصدر

```bash
git clone https://github.com/if12is/Mo-Music.git
cd Mo-Music
cp .env.example .env
flutter pub get
flutter run
```

## الترخيص

مرخّص تحت **GNU GPL v3.0**. راجع [CREDITS.md](CREDITS.md) لإقرارات المشاريع الأصلية.

Made by **Ahmed Elsayed** · [if12is/Mo-Music](https://github.com/if12is/Mo-Music)
