export interface ForumRaw {
  id: string;
  fgroup: string;
  sort: string;
  name: string;
  showName?: string;
  msg: string;
  interval: string;
  createdAt: string;
  updateAt: string;
  status: string;
}

export class Forum {
  raw: ForumRaw;

  constructor(raw: ForumRaw) {
    this.raw = raw;
  }

  get id(): number {
    return Number(this.raw.id);
  }

  get name(): string {
    return this.raw.name;
  }

  get displayName(): string {
    const showName = this.raw.showName;
    if (showName !== undefined && showName !== null && showName.length > 0) {
      return showName;
    }
    return this.raw.name;
  }

  get description(): string {
    return this.raw.msg;
  }

  get sort(): number {
    return Number(this.raw.sort);
  }

  isValid(): boolean {
    return !(this.raw.fgroup === '42' && this.raw.sort === '42' && this.raw.name === '42' && this.raw.msg === '42');
  }
}

export interface CommunityRaw {
  id: string;
  sort: string;
  name: string;
  status: string;
  forums: ForumRaw[];
}

export class Community {
  raw: CommunityRaw;

  constructor(raw: CommunityRaw) {
    this.raw = raw;
  }

  get id(): number {
    return Number(this.raw.id);
  }

  get name(): string {
    return this.raw.name;
  }

  get forums(): Forum[] {
    return this.raw.forums.map(f => new Forum(f)).filter(f => f.isValid());
  }
}

export interface TimelineRaw {
  id: string;
  name: string;
  display_name: string;
  notice: string;
  max_page: number;
}

export class Timeline {
  raw: TimelineRaw;

  constructor(raw: TimelineRaw) {
    this.raw = raw;
  }

  get id(): number {
    return Number(this.raw.id);
  }

  get name(): string {
    return this.raw.name;
  }

  get displayName(): string {
    const displayName = this.raw.display_name;
    if (displayName !== undefined && displayName !== null && displayName.length > 0) {
      return displayName;
    }
    return this.raw.name;
  }

  get notice(): string {
    return this.raw.notice;
  }

  get maxPage(): number {
    return this.raw.max_page;
  }
}
