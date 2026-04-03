import { preferences } from "@kit.ArkData";
import { common } from "@kit.AbilityKit";

export class SettingsManager {
  private static instance: SettingsManager;
  private context: common.UIAbilityContext | null = null;
  private preferencesStore: preferences.Preferences | null = null;
  private static readonly STORE_NAME: string = "app_settings";
  private static readonly READ_ANNOUNCEMENT_IDS_KEY: string = "read_announcement_ids";
  private static readonly FAVORITE_EMOJIS_KEY: string = "favorite_emojis";
  private static readonly EMOJI_CATEGORY_KEY: string = "emoji_category";

  private readAnnouncementIds: number[] = [];
  private favoriteEmojis: string[] = [];
  private emojiCategoryIndex: number = 0;
  private initPromise: Promise<void> | null = null;

  private constructor() {}

  static getInstance(): SettingsManager {
    if (!SettingsManager.instance) {
      SettingsManager.instance = new SettingsManager();
    }
    return SettingsManager.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    this.initPromise = this.doInit();
    return this.initPromise;
  }

  private async doInit(): Promise<void> {
    try {
      this.preferencesStore = await preferences.getPreferences(
        this.context!,
        SettingsManager.STORE_NAME,
      );
      await this.loadReadAnnouncementIds();
      await this.loadFavoriteEmojis();
      await this.loadEmojiCategory();
      console.info(
        `[SettingsManager] Init complete, readAnnouncementIds: ${this.readAnnouncementIds.length}, favoriteEmojis: ${this.favoriteEmojis.length}`,
      );
    } catch (error) {
      console.error("[SettingsManager] Init failed:", error);
    }
  }

  async waitForInit(): Promise<void> {
    if (this.initPromise) {
      return this.initPromise;
    }
    console.warn(
      `[SettingsManager] waitForInit called but initPromise is null, init may not have been called`,
    );
  }

  private async loadReadAnnouncementIds(): Promise<void> {
    if (!this.preferencesStore) {
      return;
    }

    try {
      const idsJson: string = (await this.preferencesStore.get(
        SettingsManager.READ_ANNOUNCEMENT_IDS_KEY,
        "[]",
      )) as string;
      this.readAnnouncementIds = JSON.parse(idsJson) as number[];
    } catch (error) {
      console.error("[SettingsManager] Load read announcement ids failed:", error);
      this.readAnnouncementIds = [];
    }
  }

  private async loadFavoriteEmojis(): Promise<void> {
    if (!this.preferencesStore) {
      return;
    }

    try {
      const emojisJson: string = (await this.preferencesStore.get(
        SettingsManager.FAVORITE_EMOJIS_KEY,
        "[]",
      )) as string;
      this.favoriteEmojis = JSON.parse(emojisJson) as string[];
    } catch (error) {
      console.error("[SettingsManager] Load favorite emojis failed:", error);
      this.favoriteEmojis = [];
    }
  }

  private async loadEmojiCategory(): Promise<void> {
    if (!this.preferencesStore) {
      return;
    }

    try {
      this.emojiCategoryIndex = (await this.preferencesStore.get(
        SettingsManager.EMOJI_CATEGORY_KEY,
        0,
      )) as number;
    } catch (error) {
      console.error("[SettingsManager] Load emoji category failed:", error);
      this.emojiCategoryIndex = 0;
    }
  }

  private async saveFavoriteEmojis(): Promise<void> {
    if (!this.preferencesStore) {
      return;
    }

    try {
      const emojisJson: string = JSON.stringify(this.favoriteEmojis);
      await this.preferencesStore.put(SettingsManager.FAVORITE_EMOJIS_KEY, emojisJson);
      await this.preferencesStore.flush();
    } catch (error) {
      console.error("[SettingsManager] Save favorite emojis failed:", error);
    }
  }

  private async saveEmojiCategory(): Promise<void> {
    if (!this.preferencesStore) {
      return;
    }

    try {
      await this.preferencesStore.put(SettingsManager.EMOJI_CATEGORY_KEY, this.emojiCategoryIndex);
      await this.preferencesStore.flush();
    } catch (error) {
      console.error("[SettingsManager] Save emoji category failed:", error);
    }
  }

  private async saveReadAnnouncementIds(): Promise<void> {
    if (!this.preferencesStore) {
      return;
    }

    try {
      const idsJson: string = JSON.stringify(this.readAnnouncementIds);
      await this.preferencesStore.put(SettingsManager.READ_ANNOUNCEMENT_IDS_KEY, idsJson);
      await this.preferencesStore.flush();
    } catch (error) {
      console.error("[SettingsManager] Save read announcement ids failed:", error);
    }
  }

  getReadAnnouncementIds(): number[] {
    return [...this.readAnnouncementIds];
  }

  async setAnnouncementRead(threadId: number): Promise<void> {
    if (this.readAnnouncementIds.indexOf(threadId) === -1) {
      this.readAnnouncementIds.push(threadId);
      await this.saveReadAnnouncementIds();
      console.info(`[SettingsManager] Marked announcement ${threadId} as read`);
    }
  }

  isAnnouncementRead(threadId: number): boolean {
    return this.readAnnouncementIds.indexOf(threadId) !== -1;
  }

  getFavoriteEmojis(): string[] {
    return [...this.favoriteEmojis];
  }

  async addFavoriteEmoji(emoji: string): Promise<void> {
    const existingIndex: number = this.favoriteEmojis.indexOf(emoji);
    if (existingIndex !== -1) {
      this.favoriteEmojis.splice(existingIndex, 1);
    }
    this.favoriteEmojis.unshift(emoji);
    if (this.favoriteEmojis.length > 20) {
      this.favoriteEmojis = this.favoriteEmojis.slice(0, 20);
    }
    await this.saveFavoriteEmojis();
    console.info(`[SettingsManager] Added favorite emoji: ${emoji}`);
  }

  getEmojiCategoryIndex(): number {
    return this.emojiCategoryIndex;
  }

  async setEmojiCategoryIndex(index: number): Promise<void> {
    this.emojiCategoryIndex = index;
    await this.saveEmojiCategory();
    console.info(`[SettingsManager] Set emoji category index: ${index}`);
  }
}
