export interface CookieRaw {
  cookieHash: string;
  cookieName: string;
  cookieDisplayName: string;
  lastUsedAt: number;
  domain: string;
}

export class Cookie {
  private _raw: CookieRaw;

  constructor(raw: CookieRaw) {
    this._raw = raw;
  }

  get raw(): CookieRaw {
    return this._raw;
  }

  get cookieHash(): string {
    return this._raw.cookieHash;
  }

  get cookieName(): string {
    return this._raw.cookieName;
  }

  get cookieDisplayName(): string {
    return this._raw.cookieDisplayName;
  }

  set cookieDisplayName(value: string) {
    this._raw.cookieDisplayName = value;
  }

  get lastUsedAt(): number {
    return this._raw.lastUsedAt;
  }

  set lastUsedAt(value: number) {
    this._raw.lastUsedAt = value;
  }

  get domain(): string {
    return this._raw.domain;
  }

  getApiHeaderCookieHash(): string {
    return `userhash=${this.cookieHash}`;
  }

  static create(cookieHash: string, cookieName: string, displayName: string, domain: string): Cookie {
    return new Cookie({
      cookieHash: cookieHash,
      cookieName: cookieName,
      cookieDisplayName: displayName,
      lastUsedAt: Date.now(),
      domain: domain
    });
  }

  toJSON(): string {
    return JSON.stringify(this._raw);
  }

  static fromJSON(json: string): Cookie {
    const raw: CookieRaw = JSON.parse(json) as CookieRaw;
    return new Cookie(raw);
  }
}
