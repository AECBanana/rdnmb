export interface PostRaw {
  id: string;
  img?: string;
  ext?: string;
  now?: string;
  userid?: string;
  name?: string;
  email?: string;
  title?: string;
  content?: string;
  sage?: string;
  admin?: string;
}

export class Post {
  raw: PostRaw;

  constructor(raw: PostRaw) {
    this.raw = raw;
  }

  get id(): number {
    return Number(this.raw.id);
  }

  get attachmentBase(): string | null {
    const img = this.raw.img;
    if (img !== undefined && img !== null && img !== "") {
      return img;
    }
    return null;
  }

  get attachmentExtension(): string | null {
    const ext = this.raw.ext;
    if (ext !== undefined && ext !== null && ext !== "") {
      return ext;
    }
    return null;
  }

  get attachmentUrl(): string | null {
    if (this.attachmentBase && this.attachmentExtension) {
      return `https://image.nmb.best/image/${this.attachmentBase}${this.attachmentExtension}`;
    }
    return null;
  }

  get thumbnailUrl(): string | null {
    if (this.attachmentBase && this.attachmentExtension) {
      return `https://image.nmb.best/thumb/${this.attachmentBase}${this.attachmentExtension}`;
    }
    return null;
  }

  get createdAtText(): string {
    const now = this.raw.now;
    return now !== undefined && now !== null ? now : "";
  }

  get userId(): string {
    const userid = this.raw.userid;
    return userid !== undefined && userid !== null ? userid : "";
  }

  get name(): string | null {
    const name = this.raw.name;
    if (name !== undefined && name !== null && name !== "无名氏") {
      return name;
    }
    return null;
  }

  get email(): string | null {
    const email = this.raw.email;
    if (email !== undefined && email !== null && email !== "") {
      return email;
    }
    return null;
  }

  get title(): string | null {
    const title = this.raw.title;
    if (title !== undefined && title !== null && title !== "无标题") {
      return title;
    }
    return null;
  }

  get content(): string {
    const content = this.raw.content;
    return content !== undefined && content !== null ? content : "";
  }

  get marked_sage(): boolean {
    const sage = this.raw.sage;
    return sage !== undefined && sage !== null && sage === "1";
  }

  get marked_admin(): boolean {
    const admin = this.raw.admin;
    return admin !== undefined && admin !== null && admin === "1";
  }
}

export interface ThreadBodyRaw extends PostRaw {
  ReplyCount?: string;
  fid?: string;
}

export class ThreadBody extends Post {
  raw: ThreadBodyRaw;

  constructor(raw: ThreadBodyRaw) {
    super(raw);
    this.raw = raw;
  }

  get totalReplyCount(): number {
    const replyCount = this.raw.ReplyCount;
    if (replyCount !== undefined && replyCount !== null) {
      return Number(replyCount);
    }
    return 0;
  }

  get boardId(): number | null {
    const fid = this.raw.fid;
    if (fid !== undefined && fid !== null) {
      return Number(fid);
    }
    return null;
  }
}

export interface ThreadPageRaw extends ThreadBodyRaw {
  Replies?: PostRaw[];
}

export class ThreadPage extends ThreadBody {
  raw: ThreadPageRaw;

  private repliesCache: Post[] = [];

  constructor(raw: ThreadPageRaw) {
    super(raw);
    this.raw = raw;
    const replys = this.raw.Replies;
    if (replys !== undefined && replys !== null) {
      for (let i = 0; i < replys.length; i++) {
        this.repliesCache.push(new Post(replys[i]));
      }
    }
  }

  get replies(): Post[] {
    return this.repliesCache;
  }

  get replyCount(): number {
    return this.repliesCache.length;
  }

  addReplies(newReplies: PostRaw[]): Post[] {
    const addedPosts: Post[] = [];
    for (let i = 0; i < newReplies.length; i++) {
      const post = new Post(newReplies[i]);
      this.repliesCache.push(post);
      addedPosts.push(post);
    }
    return addedPosts;
  }
}

export interface BoardThreadRaw extends ThreadBodyRaw {
  Replies?: PostRaw[];
}

export class BoardThread extends ThreadBody {
  raw: BoardThreadRaw;

  constructor(raw: BoardThreadRaw) {
    super(raw);
    this.raw = raw;
  }

  get lastReplies(): Post[] {
    const replys = this.raw.Replies;
    if (replys !== undefined && replys !== null) {
      return replys.map((postRaw: PostRaw) => new Post(postRaw));
    }
    return [];
  }
}

export interface BoardRaw {
  id: string;
  name: string;
  msg: string;
}

export class Board {
  raw: BoardRaw;

  constructor(raw: BoardRaw) {
    this.raw = raw;
  }

  get id(): number {
    return Number(this.raw.id);
  }

  get name(): string {
    return this.raw.name;
  }

  get description(): string {
    return this.raw.msg;
  }
}
