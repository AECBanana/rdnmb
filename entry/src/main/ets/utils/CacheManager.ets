import { CacheManager as LibCacheManager } from '@bigwinepot/cache_manager';
import { common } from '@kit.AbilityKit';
import { Community, Timeline } from '../models/Forum';
import { BoardThread, BoardThreadRaw } from '../models/Post';

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
      diskCacheFolder: 'app_cache',
      maxMemorySize: 50 * 1024 * 1024,
      maxDiskSize: 200 * 1024 * 1024,
      defaultExpireTime: 5 * 60 * 1000,
      cleanupInterval: 60 * 60 * 1000,
    });
    
    this.initialized = true;
    console.info('[CacheManager] Initialized with @bigwinepot/cache_manager');
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
      page: page
    };
    console.info(`[CacheManager] setBoardCache: saving ${threadsRaw.length} threads for key ${key}`);
    await this.libCacheManager.put(key, cacheData, 5 * 60 * 1000);
  }

  async getBoardCache(boardId: number, page: number): Promise<BoardCacheData | null> {
    const key = `board_${boardId}_${page}`;
    try {
      const cached: ESObject | null = await this.libCacheManager.get<ESObject>(key);
      console.info(`[CacheManager] getBoardCache: cached=${cached !== null}, key=${key}`);
      
      if (cached !== null && cached.threadsRaw) {
        const threadsRaw: ESObject[] = cached.threadsRaw as ESObject[];
        console.info(`[CacheManager] getBoardCache: threadsRaw is array=${Array.isArray(threadsRaw)}, length=${threadsRaw.length}`);
        
        if (Array.isArray(threadsRaw) && threadsRaw.length > 0) {
          const reconstructedThreads: BoardThread[] = [];
          for (let i = 0; i < threadsRaw.length; i++) {
            const raw: BoardThreadRaw = threadsRaw[i] as BoardThreadRaw;
            reconstructedThreads.push(new BoardThread(raw));
          }
          console.info(`[CacheManager] getBoardCache: reconstructed ${reconstructedThreads.length} threads`);
          return {
            threads: reconstructedThreads,
            lastUpdate: cached.lastUpdate !== undefined ? cached.lastUpdate as number : Date.now(),
            boardId: cached.boardId !== undefined ? cached.boardId as number : boardId,
            page: cached.page !== undefined ? cached.page as number : page
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
