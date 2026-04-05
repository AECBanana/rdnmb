export class FontConfig {
  static readonly APP_STORAGE_SCALE = "font_scale";

  static readonly TITLE_VP: number = 18;
  static readonly BODY_VP: number = 16;
  static readonly SECONDARY_VP: number = 14;
  static readonly TERTIARY_VP: number = 12;

  static init(scale: number = 1.0): void {
    AppStorage.setOrCreate<number>(FontConfig.APP_STORAGE_SCALE, scale);
  }

  static setScale(scale: number): void {
    AppStorage.setOrCreate<number>(FontConfig.APP_STORAGE_SCALE, scale);
  }

  static getScale(): number {
    return AppStorage.get<number>(FontConfig.APP_STORAGE_SCALE) ?? 1.0;
  }

  static getTitleVp(): number {
    return Math.round(FontConfig.TITLE_VP * FontConfig.getScale());
  }

  static getBodyVp(): number {
    return Math.round(FontConfig.BODY_VP * FontConfig.getScale());
  }

  static getSecondaryVp(): number {
    return Math.round(FontConfig.SECONDARY_VP * FontConfig.getScale());
  }

  static getTertiaryVp(): number {
    return Math.round(FontConfig.TERTIARY_VP * FontConfig.getScale());
  }
}
