export interface FavoriteThreadRaw {
  id: number;
  title: string;
  content: string;
  thumbnailUrl: string | null;
  userId: string;
  createdAt: string;
  savedAt: number;
  fid: number | null;
  replyCount: number;
}

export class FavoriteThread {
  raw: FavoriteThreadRaw;

  constructor(raw: FavoriteThreadRaw) {
    this.raw = raw;
  }

  get id(): number {
    return this.raw.id;
  }

  get title(): string {
    return this.raw.title;
  }

  get content(): string {
    return this.raw.content;
  }

  get thumbnailUrl(): string | null {
    return this.raw.thumbnailUrl;
  }

  get userId(): string {
    return this.raw.userId;
  }

  get createdAt(): string {
    return this.raw.createdAt;
  }

  get savedAt(): number {
    return this.raw.savedAt;
  }

  get fid(): number | null {
    return this.raw.fid;
  }

  get replyCount(): number {
    return this.raw.replyCount;
  }

  toJSON(): FavoriteThreadRaw {
    return this.raw;
  }

  static fromJSON(json: FavoriteThreadRaw): FavoriteThread {
    return new FavoriteThread(json);
  }
}
