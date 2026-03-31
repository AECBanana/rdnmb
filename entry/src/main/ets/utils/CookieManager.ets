import { preferences } from "@kit.ArkData";
import { common } from "@kit.AbilityKit";
import { Cookie, CookieRaw } from "../models/Cookie";

export interface CookieInfo {
  cookieHash: string;
  cookieName: string;
}

export class CookieManager {
  private static instance: CookieManager;
  private context: common.UIAbilityContext | null = null;
  private preferencesStore: preferences.Preferences | null = null;
  private static readonly STORE_NAME: string = "cookie_store";
  private static readonly COOKIES_KEY: string = "cookies";
  private static readonly SELECTED_COOKIE_KEY: string = "selected_cookie_hash";
  private static readonly DOMAIN: string = "nmbxd.com";

  private cookies: Cookie[] = [];
  private selectedCookieHash: string = "";
  private initPromise: Promise<void> | null = null;

  private constructor() {}

  static getInstance(): CookieManager {
    if (!CookieManager.instance) {
      CookieManager.instance = new CookieManager();
    }
    return CookieManager.instance;
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
        CookieManager.STORE_NAME,
      );
      await this.loadCookies();
      await this.loadSelectedCookie();
      console.info(
        `[CookieManager] Init complete, cookies: ${this.cookies.length}, selected: ${this.selectedCookieHash}`,
      );
    } catch (error) {
      console.error("[CookieManager] Init failed:", error);
    }
  }

  async waitForInit(): Promise<void> {
    if (this.initPromise) {
      return this.initPromise;
    }
    console.warn(
      `[CookieManager] waitForInit called but initPromise is null, init may not have been called`,
    );
  }

  private async loadCookies(): Promise<void> {
    if (!this.preferencesStore) {
      return;
    }

    try {
      const cookiesJson: string = (await this.preferencesStore.get(
        CookieManager.COOKIES_KEY,
        "[]",
      )) as string;
      const cookiesArray: CookieRaw[] = JSON.parse(cookiesJson) as CookieRaw[];
      this.cookies = [];
      for (let i: number = 0; i < cookiesArray.length; i++) {
        this.cookies.push(new Cookie(cookiesArray[i]));
      }
      this.sortByLastUsed();
    } catch (error) {
      console.error("[CookieManager] Load cookies failed:", error);
      this.cookies = [];
    }
  }

  private async loadSelectedCookie(): Promise<void> {
    if (!this.preferencesStore) {
      return;
    }

    try {
      this.selectedCookieHash = (await this.preferencesStore.get(
        CookieManager.SELECTED_COOKIE_KEY,
        "",
      )) as string;
    } catch (error) {
      console.error("[CookieManager] Load selected cookie failed:", error);
      this.selectedCookieHash = "";
    }
  }

  private async saveCookies(): Promise<void> {
    if (!this.preferencesStore) {
      return;
    }

    try {
      const cookiesArray: CookieRaw[] = [];
      for (let i: number = 0; i < this.cookies.length; i++) {
        cookiesArray.push(this.cookies[i].raw);
      }
      const cookiesJson: string = JSON.stringify(cookiesArray);
      await this.preferencesStore.put(CookieManager.COOKIES_KEY, cookiesJson);
      await this.preferencesStore.flush();
    } catch (error) {
      console.error("[CookieManager] Save cookies failed:", error);
    }
  }

  private async saveSelectedCookie(): Promise<void> {
    if (!this.preferencesStore) {
      return;
    }

    try {
      await this.preferencesStore.put(CookieManager.SELECTED_COOKIE_KEY, this.selectedCookieHash);
      await this.preferencesStore.flush();
    } catch (error) {
      console.error("[CookieManager] Save selected cookie failed:", error);
    }
  }

  private sortByLastUsed(): void {
    this.cookies.sort((a: Cookie, b: Cookie): number => b.lastUsedAt - a.lastUsedAt);
  }

  getCookies(): Cookie[] {
    return this.cookies;
  }

  getSelectedCookieHash(): string {
    console.info(
      `[CookieManager] getSelectedCookieHash called, selectedCookieHash: ${this.selectedCookieHash}, cookies count: ${this.cookies.length}`,
    );
    if (this.selectedCookieHash.length > 0) {
      const cookie: Cookie | null = this.getCookieByHash(this.selectedCookieHash);
      if (cookie) {
        console.info(
          `[CookieManager] Returning selected cookie hash: ${this.selectedCookieHash.substring(0, 8)}...`,
        );
        return this.selectedCookieHash;
      }
    }
    if (this.cookies.length > 0) {
      const hash: string = this.cookies[0].cookieHash;
      console.info(`[CookieManager] Returning first cookie hash: ${hash.substring(0, 8)}...`);
      return hash;
    }
    console.warn(`[CookieManager] No cookies available`);
    return "";
  }

  getSelectedCookie(): Cookie | null {
    if (this.selectedCookieHash.length > 0) {
      const cookie: Cookie | null = this.getCookieByHash(this.selectedCookieHash);
      if (cookie) {
        return cookie;
      }
    }
    if (this.cookies.length > 0) {
      return this.cookies[0];
    }
    return null;
  }

  async setSelectedCookie(cookieHash: string): Promise<void> {
    const cookie: Cookie | null = this.getCookieByHash(cookieHash);
    if (cookie) {
      this.selectedCookieHash = cookieHash;
      cookie.lastUsedAt = Date.now();
      this.sortByLastUsed();
      await this.saveSelectedCookie();
      await this.saveCookies();
    }
  }

  getFirstCookieHash(): string | null {
    if (this.selectedCookieHash.length > 0) {
      const cookie: Cookie | null = this.getCookieByHash(this.selectedCookieHash);
      if (cookie) {
        return cookie.getApiHeaderCookieHash();
      }
    }
    if (this.cookies.length > 0) {
      return this.cookies[0].getApiHeaderCookieHash();
    }
    return null;
  }

  getFirstCookieHashValue(): string | null {
    if (this.cookies.length > 0) {
      return this.cookies[0].cookieHash;
    }
    return null;
  }

  getCookieInfo(): CookieInfo {
    const info: CookieInfo = {
      cookieHash: "",
      cookieName: "",
    };
    console.info(
      `[CookieManager] getCookieInfo: cookies.length=${this.cookies.length}, selectedCookieHash="${this.selectedCookieHash.substring(0, 8)}..."`,
    );
    if (this.selectedCookieHash.length > 0) {
      const cookie: Cookie | null = this.getCookieByHash(this.selectedCookieHash);
      if (cookie) {
        info.cookieHash = cookie.cookieHash;
        info.cookieName = cookie.cookieName;
        console.info(
          `[CookieManager] getCookieInfo: returning selected cookie, hash="${info.cookieHash.substring(0, 8)}..."`,
        );
        return info;
      }
    }
    if (this.cookies.length > 0) {
      info.cookieHash = this.cookies[0].cookieHash;
      info.cookieName = this.cookies[0].cookieName;
      console.info(
        `[CookieManager] getCookieInfo: returning first cookie, hash="${info.cookieHash.substring(0, 8)}..."`,
      );
    } else {
      console.warn(`[CookieManager] getCookieInfo: no cookies available`);
    }
    return info;
  }

  getCookieByHash(cookieHash: string): Cookie | null {
    for (let i: number = 0; i < this.cookies.length; i++) {
      if (this.cookies[i].cookieHash === cookieHash) {
        return this.cookies[i];
      }
    }
    return null;
  }

  getCookieDisplayName(cookieName: string): string | null {
    for (let i: number = 0; i < this.cookies.length; i++) {
      if (this.cookies[i].cookieName === cookieName) {
        return this.cookies[i].cookieDisplayName;
      }
    }
    return null;
  }

  async addCookie(cookieHash: string, cookieName: string, displayName: string): Promise<void> {
    console.info(
      `[CookieManager] addCookie called, hash: ${cookieHash.substring(0, 8)}..., name: ${cookieName}, displayName: ${displayName}`,
    );
    const existingCookie: Cookie | null = this.getCookieByHash(cookieHash);
    if (existingCookie) {
      existingCookie.cookieDisplayName = displayName;
      existingCookie.lastUsedAt = Date.now();
      this.selectedCookieHash = cookieHash;
      await this.saveSelectedCookie();
    } else {
      const newCookie: Cookie = Cookie.create(
        cookieHash,
        cookieName,
        displayName,
        CookieManager.DOMAIN,
      );
      this.cookies.push(newCookie);
      this.selectedCookieHash = cookieHash;
      await this.saveSelectedCookie();
    }
    this.sortByLastUsed();
    await this.saveCookies();
    console.info(
      `[CookieManager] Cookie saved, total cookies: ${this.cookies.length}, selectedHash: ${this.selectedCookieHash.substring(0, 8)}...`,
    );
  }

  async deleteCookie(cookieHash: string): Promise<void> {
    const newCookies: Cookie[] = [];
    for (let i: number = 0; i < this.cookies.length; i++) {
      if (this.cookies[i].cookieHash !== cookieHash) {
        newCookies.push(this.cookies[i]);
      }
    }
    this.cookies = newCookies;

    if (this.selectedCookieHash === cookieHash) {
      if (this.cookies.length > 0) {
        this.selectedCookieHash = this.cookies[0].cookieHash;
      } else {
        this.selectedCookieHash = "";
      }
      await this.saveSelectedCookie();
    }

    await this.saveCookies();
  }

  async setLastUsedCookie(cookieHash: string): Promise<void> {
    const cookie: Cookie | null = this.getCookieByHash(cookieHash);
    if (cookie) {
      cookie.lastUsedAt = Date.now();
      this.sortByLastUsed();
      await this.saveCookies();
    }
  }

  async updateCookieDisplayName(cookieHash: string, displayName: string): Promise<void> {
    const cookie: Cookie | null = this.getCookieByHash(cookieHash);
    if (cookie) {
      cookie.cookieDisplayName = displayName;
      await this.saveCookies();
    }
  }

  hasCookies(): boolean {
    return this.cookies.length > 0;
  }
}
