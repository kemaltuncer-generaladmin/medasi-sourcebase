# SourceBase Tasarım Tutarlılığı ve Design System Planı

## 📋 Durum Analizi

### Tespit Edilen Sorunlar

Mevcut kod tabanında yapılan inceleme sonucunda şu tasarım tutarsızlıkları tespit edildi:

#### 1. **Buton Bileşenleri Tutarsızlığı**
- **Auth ekranlarında**: [`GradientActionButton`](lib/features/auth/presentation/widgets/auth_widgets.dart:201), [`OutlineActionButton`](lib/features/auth/presentation/widgets/auth_widgets.dart:253)
- **Drive ekranlarında**: [`PrimaryGradientButton`](lib/features/drive/presentation/widgets/drive_ui.dart:328), [`OutlineIconButton`](lib/features/drive/presentation/widgets/drive_ui.dart:391)
- **SourceLab ekranlarında**: [`_PrimaryLabButton`](lib/features/sourcelab/presentation/screens/source_lab_screen.dart:3710), [`_SecondaryLabButton`](lib/features/sourcelab/presentation/screens/source_lab_screen.dart:3783), [`_SmallActionButton`](lib/features/sourcelab/presentation/screens/source_lab_screen.dart:3829)
- **BaseForce ekranlarında**: [`_SegmentButton`](lib/features/baseforce/presentation/screens/baseforce_screen.dart:3196), [`_TopicButton`](lib/features/baseforce/presentation/screens/baseforce_screen.dart:4577)

**Sorun**: Her feature kendi buton bileşenlerini oluşturmuş, ortak bir tasarım dili yok.

#### 2. **Panel/Card Bileşenleri Tutarsızlığı**
- BaseForce: `_BasePanel` (radius: 16, padding: 18)
- SourceLab: `_LabPanel` (farklı padding değerleri)
- Auth: Özel container'lar (radius: 11, farklı shadow değerleri)

#### 3. **Renk Kullanımı**
- [`AppColors`](lib/core/theme/app_colors.dart:3) sınıfı mevcut ve iyi tanımlanmış
- Ancak bazı yerlerde hard-coded renkler kullanılıyor
- Gradient'ler tutarlı kullanılmıyor

#### 4. **Tipografi Tutarsızlığı**
- Font boyutları: 13, 14.5, 15, 16, 18, 19, 20, 21, 22, 23, 24, 34, 44, 46
- Font weight'ler: w400, w500, w600, w700, w800, w900
- Sistematik bir tipografi skalası yok

#### 5. **Boşluk (Spacing) Sistemi**
- Padding değerleri: 4, 8, 10, 12, 14, 16, 18, 20, 22, 24, 28, 32, 34, 36, 38, 44
- Sistematik bir spacing sistemi yok (8'in katları gibi)

#### 6. **Icon Butonlar**
- [`_RoundIconButton`](lib/features/baseforce/presentation/screens/baseforce_screen.dart:345) (BaseForce)
- [`_RoundIconButton`](lib/features/central_ai/presentation/screens/central_ai_screen.dart:259) (CentralAI)
- [`_RoundIconButton`](lib/features/profile/presentation/screens/profile_screen.dart:295) (Profile)
- Her feature'da aynı isimle farklı implementasyonlar

---

## 🎯 Çözüm Stratejisi

### Faz 1: Design System Altyapısı (Öncelik: Yüksek)

#### 1.1 Ortak Widget Kütüphanesi Oluşturma

**Dizin Yapısı:**
```
lib/
  core/
    design_system/
      buttons/
        sb_primary_button.dart
        sb_secondary_button.dart
        sb_outline_button.dart
        sb_icon_button.dart
        sb_text_button.dart
      cards/
        sb_card.dart
        sb_panel.dart
      inputs/
        sb_text_field.dart
        sb_search_field.dart
      typography/
        sb_text_styles.dart
      spacing/
        sb_spacing.dart
      constants/
        sb_dimensions.dart
```

#### 1.2 Buton Sistemi Standardizasyonu

**Buton Tipleri:**

1. **SBPrimaryButton** (Gradient buton)
   - Kullanım: Ana aksiyonlar (Giriş Yap, Kaydet, Oluştur)
   - Özellikler: Gradient background, shadow, bold text
   - Varyantlar: Normal (64px), Large (72px), Small (56px)

2. **SBSecondaryButton** (Outline buton)
   - Kullanım: İkincil aksiyonlar (İptal, Geri, Düzenle)
   - Özellikler: Border, transparent background
   - Varyantlar: Normal (58px), Large (64px), Small (52px)

3. **SBIconButton** (Yuvarlak icon buton)
   - Kullanım: Toolbar, navigation
   - Özellikler: Circle shape, shadow, icon only
   - Boyutlar: 50px (default), 44px (compact), 56px (large)

4. **SBTextButton** (Minimal buton)
   - Kullanım: Linkler, az önemli aksiyonlar
   - Özellikler: Text only, no background

**Ortak Özellikler:**
- Semantik etiketleme zorunlu
- Tooltip desteği
- Loading state
- Disabled state
- Ripple effect (InkWell)

#### 1.3 Tipografi Sistemi

**Font Skalası (8px base):**
```dart
class SBTextStyles {
  // Display (Hero başlıklar)
  static const display1 = TextStyle(fontSize: 48, fontWeight: FontWeight.w900, height: 1.08);
  static const display2 = TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 1.1);
  
  // Heading (Bölüm başlıkları)
  static const heading1 = TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2);
  static const heading2 = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.25);
  static const heading3 = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3);
  
  // Body (İçerik metinleri)
  static const bodyLarge = TextStyle(fontSize: 18, fontWeight: FontWeight.w500, height: 1.4);
  static const bodyMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5);
  static const bodySmall = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.5);
  
  // Label (Buton, form label)
  static const labelLarge = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.2);
  static const labelMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2);
  static const labelSmall = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2);
  
  // Caption (Yardımcı metinler)
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3);
}
```

#### 1.4 Spacing Sistemi

**8px Grid Sistemi:**
```dart
class SBSpacing {
  static const double xs = 4;    // 0.5x
  static const double sm = 8;    // 1x
  static const double md = 16;   // 2x
  static const double lg = 24;   // 3x
  static const double xl = 32;   // 4x
  static const double xxl = 48;  // 6x
  static const double xxxl = 64; // 8x
}
```

#### 1.5 Boyutlandırma Sistemi

**Sabit Boyutlar:**
```dart
class SBDimensions {
  // Border Radius
  static const double radiusXs = 6;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusFull = 999;
  
  // Button Heights
  static const double buttonSmall = 48;
  static const double buttonMedium = 56;
  static const double buttonLarge = 64;
  static const double buttonXLarge = 72;
  
  // Icon Sizes
  static const double iconXs = 16;
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 28;
  static const double iconXl = 32;
  
  // Input Heights
  static const double inputSmall = 48;
  static const double inputMedium = 56;
  static const double inputLarge = 64;
}
```

---

### Faz 2: Bileşen Geçişi (Öncelik: Orta)

#### 2.1 Geçiş Stratejisi

**Yaklaşım: Kademeli Geçiş**
1. Yeni bileşenleri oluştur
2. Eski bileşenleri deprecated olarak işaretle
3. Feature bazında geçiş yap
4. Eski bileşenleri kaldır

**Geçiş Sırası:**
1. **Auth ekranları** (En basit, az bileşen)
2. **Profile ekranları** (Orta karmaşıklık)
3. **Drive ekranları** (Ortak kullanım)
4. **BaseForce ekranları** (Karmaşık)
5. **SourceLab ekranları** (En karmaşık)

#### 2.2 Buton Geçiş Tablosu

| Eski Bileşen | Yeni Bileşen | Kullanım Yeri |
|--------------|--------------|---------------|
| `GradientActionButton` | `SBPrimaryButton` | Auth ekranları |
| `OutlineActionButton` | `SBSecondaryButton` | Auth ekranları |
| `PrimaryGradientButton` | `SBPrimaryButton` | Drive ekranları |
| `OutlineIconButton` | `SBSecondaryButton` | Drive ekranları |
| `_PrimaryLabButton` | `SBPrimaryButton` | SourceLab |
| `_SecondaryLabButton` | `SBSecondaryButton` | SourceLab |
| `_SmallActionButton` | `SBTextButton` | SourceLab |
| `_RoundIconButton` (tüm varyantlar) | `SBIconButton` | Tüm ekranlar |

---

### Faz 3: Panel ve Card Standardizasyonu (Öncelik: Orta)

#### 3.1 SBCard Bileşeni

**Özellikler:**
- Standart padding: 16px (md)
- Standart radius: 12px (md)
- Standart shadow: elevation 2
- Varyantlar: flat, elevated, outlined

**Kullanım:**
```dart
SBCard(
  child: Column(
    children: [
      SBText.heading3('Başlık'),
      SBSpacing.vertical(md),
      SBText.body('İçerik'),
    ],
  ),
)
```

#### 3.2 SBPanel Bileşeni

**Özellikler:**
- Daha büyük padding: 24px (lg)
- Daha büyük radius: 16px (lg)
- Daha belirgin shadow: elevation 3
- Header desteği

**Kullanım:**
```dart
SBPanel(
  title: 'Panel Başlığı',
  trailing: SBIconButton(...),
  child: ...,
)
```

---

### Faz 4: Semantik Etiketleme Standardizasyonu (Öncelik: Yüksek)

#### 4.1 Semantik Kurallar

**Zorunlu Semantik Etiketler:**

1. **Butonlar**
   ```dart
   Semantics(
     button: true,
     label: 'Açıklayıcı etiket',
     hint: 'Ne yapacağını açıkla',
     child: ...,
   )
   ```

2. **Icon-only Butonlar**
   ```dart
   Semantics(
     button: true,
     label: 'Ara', // Icon'un anlamı
     tooltip: 'Dosyalarda ara',
     child: ...,
   )
   ```

3. **Başlıklar**
   ```dart
   Semantics(
     header: true,
     label: 'Bölüm başlığı',
     child: ...,
   )
   ```

4. **Dekoratif Öğeler**
   ```dart
   ExcludeSemantics(
     child: ..., // Sadece görsel, anlam taşımayan
   )
   ```

#### 4.2 Semantik Kontrol Listesi

Her yeni widget için:
- [ ] Tüm interaktif öğeler semantik etiketli mi?
- [ ] Icon-only butonlar tooltip içeriyor mu?
- [ ] Başlıklar `header: true` ile işaretli mi?
- [ ] Dekoratif öğeler `ExcludeSemantics` ile sarılmış mı?
- [ ] Çift etiketleme yok mu? (parent + child)

---

### Faz 5: Renk Sistemi İyileştirmesi (Öncelik: Düşük)

#### 5.1 Mevcut Renk Paleti

[`AppColors`](lib/core/theme/app_colors.dart:3) zaten iyi tanımlanmış:
- Primary: `blue`, `deepBlue`, `sky`
- Secondary: `cyan`, `purple`, `orange`, `green`
- Neutral: `navy`, `ink`, `muted`, `softText`
- Background: `page`, `white`, `softBlue`, `selectedBlue`
- Semantic: `green`, `red`, `orange`

#### 5.2 İyileştirmeler

1. **Semantic Renk İsimleri Ekle**
   ```dart
   // Semantic colors
   static const success = green;
   static const error = red;
   static const warning = orange;
   static const info = blue;
   ```

2. **Opacity Varyantları**
   ```dart
   // Opacity variants
   static Color blueLight = blue.withValues(alpha: 0.1);
   static Color blueMedium = blue.withValues(alpha: 0.5);
   ```

3. **Hard-coded Renkleri Temizle**
   - Tüm `Color(0xFF...)` kullanımlarını `AppColors` ile değiştir
   - Özel renkler varsa `AppColors`'a ekle

---

## 📐 Implementasyon Detayları

### Örnek: SBPrimaryButton

```dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../constants/sb_dimensions.dart';
import '../spacing/sb_spacing.dart';
import '../typography/sb_text_styles.dart';

enum SBButtonSize { small, medium, large, xLarge }

class SBPrimaryButton extends StatelessWidget {
  const SBPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = SBButtonSize.medium,
    this.loading = false,
    this.fullWidth = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SBButtonSize size;
  final bool loading;
  final bool fullWidth;

  double get _height {
    return switch (size) {
      SBButtonSize.small => SBDimensions.buttonSmall,
      SBButtonSize.medium => SBDimensions.buttonMedium,
      SBButtonSize.large => SBDimensions.buttonLarge,
      SBButtonSize.xLarge => SBDimensions.buttonXLarge,
    };
  }

  double get _fontSize {
    return switch (size) {
      SBButtonSize.small => 16,
      SBButtonSize.medium => 18,
      SBButtonSize.large => 20,
      SBButtonSize.xLarge => 22,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || loading;
    
    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: label,
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        height: _height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: isDisabled ? null : AppColors.primaryGradient,
            color: isDisabled ? AppColors.line : null,
            borderRadius: BorderRadius.circular(SBDimensions.radiusMd),
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: ElevatedButton(
            onPressed: isDisabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: AppColors.muted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SBDimensions.radiusMd),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: SBSpacing.lg,
                vertical: SBSpacing.md,
              ),
            ),
            child: loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDisabled ? AppColors.muted : AppColors.white,
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: SBDimensions.iconMd),
                        SizedBox(width: SBSpacing.sm),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: _fontSize,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
```

---

## 🔄 Geçiş Adımları

### Adım 1: Design System Dosyalarını Oluştur (1-2 gün)

1. `lib/core/design_system/` dizinini oluştur
2. Tüm temel bileşenleri yaz:
   - Butonlar (5 tip)
   - Card/Panel (2 tip)
   - TextField (2 tip)
   - Typography helper
   - Spacing helper
   - Dimensions constants

### Adım 2: Auth Ekranlarını Güncelle (1 gün)

1. [`login_screen.dart`](lib/features/auth/presentation/screens/login_screen.dart:10) güncelle
2. [`register_screen.dart`](lib/features/auth/presentation/screens/register_screen.dart) güncelle
3. [`forgot_password_screen.dart`](lib/features/auth/presentation/screens/forgot_password_screen.dart) güncelle
4. Eski widget'ları deprecated işaretle

### Adım 3: Drive Ekranlarını Güncelle (1-2 gün)

1. Drive UI bileşenlerini yeni sisteme geçir
2. Bottom navigation'ı güncelle
3. File card'larını standartlaştır

### Adım 4: BaseForce Ekranlarını Güncelle (2-3 gün)

1. [`baseforce_screen.dart`](lib/features/baseforce/presentation/screens/baseforce_screen.dart:22) içindeki tüm özel butonları değiştir
2. Panel bileşenlerini standartlaştır
3. Factory ekranlarını güncelle

### Adım 5: SourceLab Ekranlarını Güncelle (2-3 gün)

1. [`source_lab_screen.dart`](lib/features/sourcelab/presentation/screens/source_lab_screen.dart:29) içindeki tüm özel butonları değiştir
2. Builder ekranlarını güncelle
3. Result ekranlarını güncelle

### Adım 6: Semantik Etiketleme Kontrolü (1 gün)

1. Tüm ekranları Codex ile kontrol et
2. Eksik semantik etiketleri ekle
3. Çift etiketlemeleri temizle

### Adım 7: Eski Bileşenleri Temizle (1 gün)

1. Deprecated bileşenleri kaldır
2. Kullanılmayan import'ları temizle
3. Kod kalitesi kontrolü

---

## 📊 Beklenen Faydalar

### Geliştirici Deneyimi
- ✅ Yeni ekran oluştururken tutarlı bileşenler kullanma
- ✅ Kod tekrarını azaltma
- ✅ Daha hızlı geliştirme süreci
- ✅ Daha kolay bakım

### Kullanıcı Deneyimi
- ✅ Tutarlı görsel dil
- ✅ Öngörülebilir etkileşimler
- ✅ Daha iyi erişilebilirlik
- ✅ Profesyonel görünüm

### Kod Kalitesi
- ✅ Daha az kod tekrarı
- ✅ Merkezi güncelleme imkanı
- ✅ Daha kolay test edilebilirlik
- ✅ Daha iyi dokümantasyon

---

## ⚠️ Riskler ve Önlemler

### Risk 1: Büyük Refactoring
**Önlem**: Kademeli geçiş, feature bazında ilerleme

### Risk 2: Mevcut Özelliklerin Bozulması
**Önlem**: Her feature geçişinden sonra test, eski bileşenleri hemen silmeme

### Risk 3: Geliştirme Süresinin Uzaması
**Önlem**: Öncelik sıralaması, kritik olmayan feature'ları sonraya bırakma

### Risk 4: Tasarım Değişikliklerine Direnç
**Önlem**: Görsel olarak mümkün olduğunca mevcut tasarımı koruma, sadece kod yapısını değiştirme

---

## 📝 Kontrol Listesi

### Design System Oluşturma
- [ ] `lib/core/design_system/` dizini oluşturuldu
- [ ] `SBPrimaryButton` bileşeni oluşturuldu
- [ ] `SBSecondaryButton` bileşeni oluşturuldu
- [ ] `SBIconButton` bileşeni oluşturuldu
- [ ] `SBTextButton` bileşeni oluşturuldu
- [ ] `SBCard` bileşeni oluşturuldu
- [ ] `SBPanel` bileşeni oluşturuldu
- [ ] `SBTextField` bileşeni oluşturuldu
- [ ] `SBTextStyles` helper oluşturuldu
- [ ] `SBSpacing` constants oluşturuldu
- [ ] `SBDimensions` constants oluşturuldu

### Feature Geçişleri
- [ ] Auth ekranları güncellendi
- [ ] Profile ekranları güncellendi
- [ ] Drive ekranları güncellendi
- [ ] BaseForce ekranları güncellendi
- [ ] SourceLab ekranları güncellendi
- [ ] CentralAI ekranları güncellendi

### Semantik Etiketleme
- [ ] Tüm butonlar semantik etiketli
- [ ] Tüm icon butonlar tooltip içeriyor
- [ ] Tüm başlıklar header olarak işaretli
- [ ] Dekoratif öğeler ExcludeSemantics ile sarılmış
- [ ] Çift etiketlemeler temizlendi

### Temizlik
- [ ] Eski buton bileşenleri kaldırıldı
- [ ] Kullanılmayan import'lar temizlendi
- [ ] Hard-coded renkler AppColors'a taşındı
- [ ] Kod kalitesi kontrolü yapıldı

---

## 🎨 Görsel Örnekler

### Buton Hiyerarşisi

```
┌─────────────────────────────────────┐
│  Primary Button (Gradient)          │  ← Ana aksiyon
│  [Icon] Label                        │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  Secondary Button (Outline)         │  ← İkincil aksiyon
│  [Icon] Label                        │
└─────────────────────────────────────┘

  Text Button                            ← Üçüncül aksiyon
  [Icon] Label

  ⊙  Icon Button                         ← Toolbar aksiyon
```

### Tipografi Hiyerarşisi

```
Display 1 (48px, w900)  ← Hero başlıklar
Display 2 (40px, w900)

Heading 1 (32px, w800)  ← Ana başlıklar
Heading 2 (24px, w800)  ← Alt başlıklar
Heading 3 (20px, w700)  ← Bölüm başlıkları

Body Large (18px, w500)  ← Ana içerik
Body Medium (16px, w500) ← Normal içerik
Body Small (14px, w500)  ← Küçük içerik

Label Large (18px, w700)  ← Büyük butonlar
Label Medium (16px, w700) ← Normal butonlar
Label Small (14px, w600)  ← Küçük butonlar

Caption (12px, w500)      ← Yardımcı metinler
```

### Spacing Sistemi

```
xs  = 4px   ▪
sm  = 8px   ▪▪
md  = 16px  ▪▪▪▪
lg  = 24px  ▪▪▪▪▪▪
xl  = 32px  ▪▪▪▪▪▪▪▪
xxl = 48px  ▪▪▪▪▪▪▪▪▪▪▪▪
```

---

## 📚 Referanslar

### Mevcut Kod Referansları
- Renk Sistemi: [`lib/core/theme/app_colors.dart`](lib/core/theme/app_colors.dart:3)
- Tema: [`lib/core/theme/app_theme.dart`](lib/core/theme/app_theme.dart:5)
- Auth Butonları: [`lib/features/auth/presentation/widgets/auth_widgets.dart`](lib/features/auth/presentation/widgets/auth_widgets.dart:201)
- Drive Butonları: [`lib/features/drive/presentation/widgets/drive_ui.dart`](lib/features/drive/presentation/widgets/drive_ui.dart:328)

### Design System Best Practices
- Material Design 3 Guidelines
- Flutter Widget Catalog
- Atomic Design Methodology
- 8-Point Grid System

---

## 🚀 Sonraki Adımlar

1. **Bu planı gözden geçir** ve onay al
2. **Design system dosyalarını oluştur** (Faz 1)
3. **Auth ekranlarıyla başla** (Faz 2, Adım 1)
4. **Kademeli olarak diğer feature'lara geç**
5. **Her adımda test et** ve geri bildirim al

---

## 📞 İletişim

Bu plan hakkında sorularınız veya önerileriniz varsa:
- Planı güncelleyebiliriz
- Öncelikleri değiştirebiliriz
- Yeni bileşenler ekleyebiliriz
- Geçiş stratejisini ayarlayabiliriz

**Önemli**: Bu plan, mevcut çalışan uygulamayı bozmadan, kademeli ve güvenli bir şekilde tasarım tutarlılığı sağlamak için hazırlanmıştır. Her adım test edilmeli ve onaylanmalıdır.
