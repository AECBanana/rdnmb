import { CacheManager as LibCacheManager } from "@bigwinepot/cache_manager";
import { common } from "@kit.AbilityKit";
import { Community, Timeline } from "../models/Forum";
import { BoardThread, BoardThreadRaw, ThreadPage, ThreadPageRaw } from "../models/Post";

export interface CacheData {
  communities: Community[];
  timelines: Timeline[];
  lastUpdate: number;
}


export interface BoardCacheData {
  threads: BoardThread[];
  lastUpdate: number;
  boardId: number;
  page: number;
}

export interface ImageCacheData {
  localPath: string;
  remoteUrl: string;
  lastAccess: number;
}

export interface ThreadCacheData {
  threadRaw: ThreadPageRaw;
  lastUpdate: number;
  threadId: number;
  page: number;
}

export interface ThreadReadPosition {
  threadId: number;
  page: number;
  lastReplyId: number;
  lastReadTime: number;
}

export class CacheManager {
  private static instance: CacheManager | null = null;
  private libCacheManager: LibCacheManager = LibCacheManager.getInstance();
  private initialized: boolean = false;

  private communities: Community[] = [];
  private timelines: Timeline[] = [];

  private constructor() {
    if (CacheManager.instance === null) {
      CacheManager.instance = this;
    }
    return CacheManager.instance;
  }

  static getInstance(): CacheManager {
    if (CacheManager.instance === null) {
      CacheManager.instance = new CacheManager();
    }
    return CacheManager.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.initialized) {
      return;
    }

    const cachePath = context.cacheDir;
    await this.libCacheManager.init({
      enabled: true,
      enableMemoryCache: true,
      enableDiskCache: true,
      diskCachePath: cachePath,
      diskCacheFolder: "app_cache",
      maxMemorySize: 50 * 1024 * 1024,
      // maxDiskSize: 200 * 1024 * 1024,
      // defaultExpireTime: 5 * 60 * 1000,
      // cleanupInterval: 60 * 60 * 1000,
    });

    this.initialized = true;
    console.info("[CacheManager] Initialized with @bigwinepot/cache_manager");
  }

  setCommunities(communities: Community[]): void {
    this.communities = communities;
  }

  getCommunities(): Community[] {
    return this.communities;
  }

  setTimelines(timelines: Timeline[]): void {
    this.timelines = timelines;
  }

  getTimelines(): Timeline[] {
    return this.timelines;
  }

  async setBoardCache(boardId: number, page: number, threads: BoardThread[]): Promise<void> {
    const key = `board_${boardId}_${page}`;
    const threadsRaw: BoardThreadRaw[] = [];
    for (let i = 0; i < threads.length; i++) {
      threadsRaw.push(threads[i].raw);
    }
    const cacheData: ESObject = {
      threadsRaw: threadsRaw,
      lastUpdate: Date.now(),
      boardId: boardId,
      page: page,
    };
    console.info(
      `[CacheManager] setBoardCache: saving ${threadsRaw.length} threads for key ${key}`,
    );
    await this.libCacheManager.put(key, cacheData, 5 * 60 * 1000);
  }

  async getBoardCache(boardId: number, page: number): Promise<BoardCacheData | null> {
    const key = `board_${boardId}_${page}`;
    try {
      const cached: ESObject | null = await this.libCacheManager.get<ESObject>(key);
      console.info(`[CacheManager] getBoardCache: cached=${cached !== null}, key=${key}`);

      if (cached !== null && cached.threadsRaw) {
        const threadsRaw: ESObject[] = cached.threadsRaw as ESObject[];
        console.info(
          `[CacheManager] getBoardCache: threadsRaw is array=${Array.isArray(threadsRaw)}, length=${threadsRaw.length}`,
        );

        if (Array.isArray(threadsRaw) && threadsRaw.length > 0) {
          const reconstructedThreads: BoardThread[] = [];
          for (let i = 0; i < threadsRaw.length; i++) {
            const raw: BoardThreadRaw = threadsRaw[i] as BoardThreadRaw;
            reconstructedThreads.push(new BoardThread(raw));
          }
          console.info(
            `[CacheManager] getBoardCache: reconstructed ${reconstructedThreads.length} threads`,
          );
          return {
            threads: reconstructedThreads,
            lastUpdate:
              cached.lastUpdate !== undefined ? (cached.lastUpdate as number) : Date.now(),
            boardId: cached.boardId !== undefined ? (cached.boardId as number) : boardId,
            page: cached.page !== undefined ? (cached.page as number) : page,
          };
        }
      }
      console.info(`[CacheManager] getBoardCache: no valid cache for ${key}`);
      return null;
    } catch (error) {
      console.error(`[CacheManager] getBoardCache error: ${error}`);
      return null;
    }
  }

  async clearBoardCache(boardId: number): Promise<void> {
    const key = `board_${boardId}_`;
    await this.libCacheManager.remove(key);
  }

  async setThreadCache(threadId: number, page: number, thread: ThreadPage): Promise<void> {
    const key = `thread_${threadId}_${page}`;
    const cacheData: ESObject = {
      threadRaw: thread.raw,
      lastUpdate: Date.now(),
      threadId: threadId,
      page: page,
    };
    console.info(`[CacheManager] setThreadCache: saving thread ${threadId} page ${page}`);
    await this.libCacheManager.put(key, cacheData);
  }

  async getThreadCache(threadId: number, page: number): Promise<ThreadCacheData | null> {
    const key = `thread_${threadId}_${page}`;
    try {
      const cached: ESObject | null = await this.libCacheManager.get<ESObject>(key);
      console.info(`[CacheManager] getThreadCache: cached=${cached !== null}, key=${key}`);

      if (cached !== null && cached.threadRaw) {
        const threadRaw: ThreadPageRaw = cached.threadRaw as ThreadPageRaw;
        console.info(`[CacheManager] getThreadCache: got thread ${threadId} page ${page}`);
        return {
          threadRaw: threadRaw,
          lastUpdate: cached.lastUpdate !== undefined ? (cached.lastUpdate as number) : Date.now(),
          threadId: cached.threadId !== undefined ? (cached.threadId as number) : threadId,
          page: cached.page !== undefined ? (cached.page as number) : page,
        };
      }
      console.info(`[CacheManager] getThreadCache: no valid cache for ${key}`);
      return null;
    } catch (error) {
      console.error(`[CacheManager] getThreadCache error: ${error}`);
      return null;
    }
  }

  async clearThreadCache(threadId: number): Promise<void> {
    const key = `thread_${threadId}_`;
    await this.libCacheManager.remove(key);
  }

  async setThreadReadPosition(threadId: number, page: number, lastReplyId: number): Promise<void> {
    const key = `thread_read_pos_${threadId}`;
    const positionData: ESObject = {
      threadId: threadId,
      page: page,
      lastReplyId: lastReplyId,
      lastReadTime: Date.now(),
    };
    console.info(
      `[CacheManager] setThreadReadPosition: thread ${threadId} page ${page} lastReplyId ${lastReplyId}`,
    );
    await this.libCacheManager.put(key, positionData);
  }

  async getThreadReadPosition(threadId: number): Promise<ThreadReadPosition | null> {
    const key = `thread_read_pos_${threadId}`;
    try {
      const cached: ESObject | null = await this.libCacheManager.get<ESObject>(key);
      console.info(`[CacheManager] getThreadReadPosition: cached=${cached !== null}, key=${key}`);

      if (cached !== null) {
        return {
          threadId: cached.threadId !== undefined ? (cached.threadId as number) : threadId,
          page: cached.page !== undefined ? (cached.page as number) : 1,
          lastReplyId: cached.lastReplyId !== undefined ? (cached.lastReplyId as number) : 0,
          lastReadTime:
            cached.lastReadTime !== undefined ? (cached.lastReadTime as number) : Date.now(),
        };
      }
      return null;
    } catch (error) {
      console.error(`[CacheManager] getThreadReadPosition error: ${error}`);
      return null;
    }
  }

  async clearAllCache(): Promise<void> {
    this.communities = [];
    this.timelines = [];
    await this.libCacheManager.clear();
  }

  async getCacheSize(): Promise<number> {
    return await this.libCacheManager.getCacheSize();
  }

  formatSize(bytes: number): string {
    return this.libCacheManager.formatSize(bytes);
  }

  isCacheValid(lastUpdate: number, maxAgeMs: number): boolean {
    const now = Date.now();
    const age = now - lastUpdate;
    return age < maxAgeMs;
  }
}
