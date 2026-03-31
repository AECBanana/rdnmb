import { CacheManager as LibCacheManager } from '@bigwinepot/cache_manager';
import { http } from "@kit.NetworkKit";
import { image } from "@kit.ImageKit";
import { common } from "@kit.AbilityKit";
import { BusinessError } from "@kit.BasicServicesKit";

export class ImageCacheManager {
  private static instance: ImageCacheManager;
  private libCacheManager: LibCacheManager = LibCacheManager.getInstance();
  private context: common.UIAbilityContext | null = null;
  private initialized: boolean = false;

  private constructor() {}

  static getInstance(): ImageCacheManager {
    if (!ImageCacheManager.instance) {
      ImageCacheManager.instance = new ImageCacheManager();
    }
    return ImageCacheManager.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    
    if (this.initialized) {
      return;
    }
    
    const cachePath = context.cacheDir;
    await this.libCacheManager.init({
      enabled: true,
      enableMemoryCache: true,
      enableDiskCache: true,
      diskCachePath: cachePath,
      diskCacheFolder: 'image_cache',
      // maxMemorySize: 100 * 1024 * 1024,
      // maxDiskSize: 500 * 1024 * 1024,
      // defaultExpireTime: 7 * 24 * 60 * 60 * 1000,
      // cleanupInterval: 24 * 60 * 60 * 1000,
      // strategy: MEMORY_THEN_DISK,
    });
    
    this.initialized = true;
    console.info(`[ImageCacheManager] Initialized with @bigwinepot/cache_manager`);
  }

  private hashUrl(url: string): string {
    let hash: number = 0;
    for (let i: number = 0; i < url.length; i++) {
      const char: number = url.charCodeAt(i);
      hash = (hash << 5) - hash + char;
      hash = hash & hash;
    }
    return Math.abs(hash).toString(16);
  }

  async getCachedImage(url: string): Promise<image.PixelMap | null> {
    try {
      const key = this.hashUrl(url);
      const cached = await this.libCacheManager.get<ArrayBuffer>(key, true);
      
      if (cached) {
        const imageSource: image.ImageSource = image.createImageSource(cached);
        const pixelMap: image.PixelMap = await imageSource.createPixelMap();
        imageSource.release();
        return pixelMap;
      }
      
      return null;
    } catch (error) {
      console.error(`[ImageCacheManager] Get cached image failed: ${error}`);
      return null;
    }
  }

  async downloadAndCache(url: string): Promise<image.PixelMap | null> {
    if (!url) {
      return null;
    }

    try {
      const cachedImage: image.PixelMap | null = await this.getCachedImage(url);
      if (cachedImage) {
        return cachedImage;
      }

      const httpRequest: http.HttpRequest = http.createHttp();
      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          "User-Agent": "AnoBBS-HarmonyOS/6.0",
        },
      });

      if (response.responseCode === 200) {
        const imageData: ArrayBuffer = response.result as ArrayBuffer;
        const imageSource: image.ImageSource = image.createImageSource(imageData);
        const pixelMap: image.PixelMap = await imageSource.createPixelMap();
        imageSource.release();

        await this.saveToCache(url, imageData);

        httpRequest.destroy();
        return pixelMap;
      } else {
        httpRequest.destroy();
        return null;
      }
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`[ImageCacheManager] Download failed: ${err.message}`);
      return null;
    }
  }

  private async saveToCache(url: string, data: ArrayBuffer): Promise<void> {
    try {
      const key = this.hashUrl(url);
      await this.libCacheManager.put(key, data, 7 * 24 * 60 * 60 * 1000);
      console.info(`[ImageCacheManager] Saved to cache: ${key}`);
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`[ImageCacheManager] Save to cache failed: ${err.message}`);
    }
  }

  async clearCache(): Promise<void> {
    try {
      await this.libCacheManager.clear();
      console.info(`[ImageCacheManager] Cache cleared`);
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`[ImageCacheManager] Clear cache failed: ${err.message}`);
    }
  }

  async getCacheSize(): Promise<number> {
    return await this.libCacheManager.getCacheSize();
  }

  formatSize(bytes: number): string {
    return this.libCacheManager.formatSize(bytes);
  }
}
