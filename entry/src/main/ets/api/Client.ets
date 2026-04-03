import { http } from "@kit.NetworkKit";
import { BoardThread, BoardThreadRaw, ThreadPage, ThreadPageRaw } from "../models/Post";
import { Community, CommunityRaw, Timeline, TimelineRaw } from "../models/Forum";
import {
  ApiException,
  NetworkException,
  RequiresLoginException,
  GatekeptException,
  GatekeptExceptionParams,
} from "../models/Errors";
import {
  CacheManager,
  BoardCacheData,
  ThreadCacheData,
  ThreadReadPosition,
} from "../utils/CacheManager";
import { CookieManager, CookieInfo } from "../utils/CookieManager";

export type LoginPolicy = "enforce" | "when_has_cookie" | "when_required" | "always_no";

export interface ClientConfig {
  host: string;
  userAgent: string;
  appid: string;
  userhash: string;
}

export interface RequestOptions {
  loginPolicy: LoginPolicy;
  boardGatekeeperPageNumber: number;
  threadGatekeeperPageNumber: number;
}

function createDefaultConfig(): ClientConfig {
  const config: ClientConfig = {
    host: "www.nmbxd1.com",
    userAgent: "AnoBBS-HarmonyOS/6.0",
    appid: "",
    userhash: "",
  };
  return config;
}

function createDefaultOptions(): RequestOptions {
  const opts: RequestOptions = {
    loginPolicy: "when_has_cookie",
    boardGatekeeperPageNumber: 100,
    threadGatekeeperPageNumber: 100,
  };
  return opts;
}

function mergeOptions(base: RequestOptions, override: RequestOptions): RequestOptions {
  const result: RequestOptions = {
    loginPolicy: override.loginPolicy.length > 0 ? override.loginPolicy : base.loginPolicy,
    boardGatekeeperPageNumber:
      override.boardGatekeeperPageNumber > 0
        ? override.boardGatekeeperPageNumber
        : base.boardGatekeeperPageNumber,
    threadGatekeeperPageNumber:
      override.threadGatekeeperPageNumber > 0
        ? override.threadGatekeeperPageNumber
        : base.threadGatekeeperPageNumber,
  };
  return result;
}

export class AnoBBSClient {
  private config: ClientConfig;
  private baseUrl: string;
  public imageCdn: string = "https://image.nmb.best/";
  private lastRequestTime: number = 0;
  private minRequestInterval: number = 500;
  private cacheManager: CacheManager = CacheManager.getInstance();
  private cookieManager: CookieManager = CookieManager.getInstance();

  constructor(config?: ClientConfig) {
    if (config) {
      this.config = {
        host: config.host.length > 0 ? config.host : "www.nmbxd1.com",
        userAgent: config.userAgent.length > 0 ? config.userAgent : "AnoBBS-HarmonyOS/6.0",
        appid: config.appid ? config.appid : "",
        userhash: config.userhash ? config.userhash : "",
      };
    } else {
      this.config = createDefaultConfig();
    }
    this.baseUrl = `https://${this.config.host}/`;
  }

  private async getCookieHeader(): Promise<string> {
    await this.cookieManager.waitForInit();
    console.info(`[AnoBBS] getCookieHeader: config.userhash.length=${this.config.userhash.length}`);
    if (this.config.userhash.length > 0) {
      const result = `userhash=${this.config.userhash}`;
      console.info(`[AnoBBS] Using config.userhash`);
      return result;
    }
    const cookie: CookieInfo = this.cookieManager.getCookieInfo();
    if (cookie.cookieHash.length > 0) {
      const result: string = `userhash=${cookie.cookieHash}`;
      console.info(`[AnoBBS] Using CookieManager cookie, length=${result.length}`);
      return result;
    }
    console.warn(`[AnoBBS] No cookie available!`);
    return "";
  }

  private async hasCookie(): Promise<boolean> {
    const header = await this.getCookieHeader();
    return header.length > 0;
  }

  private isRequiresLoginError(errorMsg: string): boolean {
    const loginRequiredKeywords: string[] = [
      "必须登入",
      "需要登录",
      "需要饼干",
      "请先登录",
      "未登录",
    ];
    for (let i: number = 0; i < loginRequiredKeywords.length; i++) {
      if (errorMsg.indexOf(loginRequiredKeywords[i]) !== -1) {
        return true;
      }
    }
    return false;
  }

  async getForumList(forceRefresh: boolean = false): Promise<Community[]> {
    const cached = this.cacheManager.getCommunities();
    if (!forceRefresh && cached.length > 0) {
      console.info("[AnoBBS] Using cached communities");
      return cached;
    }

    await this.waitForRateLimit();
    const data: ESObject = await this.getJson("Api/getForumList", {});

    const rawData: ESObject = data as ESObject;
    const result: Community[] = [];
    if (Array.isArray(rawData)) {
      for (let i: number = 0; i < rawData.length; i++) {
        result.push(new Community(rawData[i] as CommunityRaw));
      }
    }
    this.cacheManager.setCommunities(result);
    return result;
  }

  async getTimelineList(forceRefresh: boolean = false): Promise<Timeline[]> {
    const cached = this.cacheManager.getTimelines();
    if (!forceRefresh && cached.length > 0) {
      console.info("[AnoBBS] Using cached timelines");
      return cached;
    }

    await this.waitForRateLimit();
    const data: ESObject = await this.getJson("Api/getTimelineList", {});

    const rawData: ESObject = data as ESObject;
    const result: Timeline[] = [];
    if (Array.isArray(rawData)) {
      for (let i: number = 0; i < rawData.length; i++) {
        result.push(new Timeline(rawData[i] as TimelineRaw));
      }
    }
    this.cacheManager.setTimelines(result);
    return result;
  }

  async getBoardPage(
    boardId: number,
    pageNumber?: number,
    options?: RequestOptions,
  ): Promise<BoardThread[]> {
    const page = pageNumber !== undefined ? pageNumber : 1;
    const cached: BoardCacheData | null = await this.cacheManager.getBoardCache(boardId, page);
    if (cached !== null) {
      console.info(`[AnoBBS] Using cached board page boardId=${boardId} page=${page}`);
      return cached.threads;
    }

    await this.waitForRateLimit();
    const defaultOpts = createDefaultOptions();
    const opts = options ? mergeOptions(defaultOpts, options) : defaultOpts;
    const boardGatekeeperPageNumber = opts.boardGatekeeperPageNumber;
    const loginPolicy = opts.loginPolicy;

    if (loginPolicy === "enforce" && !(await this.hasCookie())) {
      throw new RequiresLoginException();
    }

    if (page > boardGatekeeperPageNumber) {
      const excParams: GatekeptExceptionParams = {
        message: `无论是否登陆，访问超过 ${boardGatekeeperPageNumber} 页的版块页面必会卡页`,
        context: `获取版块页面 boardId=${boardId}`,
        currentPageNumber: page,
      };
      throw new GatekeptException(excParams);
    }

    const params: ESObject = {};
    if (pageNumber !== undefined) {
      params.page = String(pageNumber);
    }

    let endpoint: string;
    if (boardId < 0) {
      endpoint = `Api/timeline/id/${Math.abs(boardId)}`;
    } else {
      endpoint = "Api/showf";
      params.id = String(boardId);
    }

    const data: ESObject = await this.getJson(endpoint, params);

    const rawData: ESObject = data as ESObject;
    const result: BoardThread[] = [];
    if (Array.isArray(rawData)) {
      for (let i: number = 0; i < rawData.length; i++) {
        result.push(new BoardThread(rawData[i] as BoardThreadRaw));
      }
    }
    await this.cacheManager.setBoardCache(boardId, page, result);
    return result;
  }

  async getThreadPage(
    threadId: number,
    pageNumber?: number,
    options?: RequestOptions,
    forceRefresh?: boolean,
  ): Promise<ThreadPage> {
    const page = pageNumber !== undefined ? pageNumber : 1;

    if (forceRefresh !== true) {
      const cached: ThreadCacheData | null = await this.cacheManager.getThreadCache(threadId, page);
      if (cached !== null) {
        console.info(`[AnoBBS] Using cached thread threadId=${threadId} page=${page}`);
        return new ThreadPage(cached.threadRaw);
      }
    }

    await this.waitForRateLimit();
    const defaultOpts = createDefaultOptions();
    const opts = options ? mergeOptions(defaultOpts, options) : defaultOpts;
    const threadGatekeeperPageNumber = opts.threadGatekeeperPageNumber;
    const loginPolicy = opts.loginPolicy;

    if (loginPolicy === "enforce" && !(await this.hasCookie())) {
      throw new RequiresLoginException();
    }

    if (page > threadGatekeeperPageNumber && !(await this.hasCookie())) {
      const excParams: GatekeptExceptionParams = {
        message: `访问超过 ${threadGatekeeperPageNumber} 页的串页面需要登陆，但并无用户`,
        context: `获取串页面 threadId=${threadId}`,
        currentPageNumber: page,
      };
      throw new GatekeptException(excParams);
    }

    const params: ESObject = {
      id: String(threadId),
    };
    if (pageNumber !== undefined) {
      params.page = String(pageNumber);
    }

    const data: ESObject = await this.getJson("Api/thread", params);
    const thread = new ThreadPage(data as ThreadPageRaw);
    await this.cacheManager.setThreadCache(threadId, page, thread);
    return thread;
  }

  async clearBoardCache(boardId: number): Promise<void> {
    await this.cacheManager.clearBoardCache(boardId);
  }

  async getBoardCache(boardId: number, page: number): Promise<BoardCacheData | null> {
    return await this.cacheManager.getBoardCache(boardId, page);
  }

  async clearThreadCache(threadId: number): Promise<void> {
    await this.cacheManager.clearThreadCache(threadId);
  }

  async getThreadCache(threadId: number, page: number): Promise<ThreadCacheData | null> {
    return await this.cacheManager.getThreadCache(threadId, page);
  }

  async setThreadReadPosition(threadId: number, page: number, lastReplyId: number): Promise<void> {
    await this.cacheManager.setThreadReadPosition(threadId, page, lastReplyId);
  }

  async getThreadReadPosition(threadId: number): Promise<ThreadReadPosition | null> {
    return await this.cacheManager.getThreadReadPosition(threadId);
  }

  async postNewThread(
    fid: string,
    content: string,
    name?: string,
    email?: string,
    title?: string,
    water?: string,
  ): Promise<string> {
    if (!(await this.hasCookie())) {
      throw new RequiresLoginException();
    }

    await this.waitForRateLimit();
    const cookieHeader: string = await this.getCookieHeader();
    const url = `${this.baseUrl}Home/Forum/doPostThread.html`;

    console.info(`[AnoBBS] Posting new thread to fid=${fid}`);

    const boundary: string = `----WebKitFormBoundary${Date.now().toString(16)}`;
    let body: string = "";

    body = body + `--${boundary}\r\n`;
    body = body + `Content-Disposition: form-data; name="fid"\r\n\r\n`;
    body = body + `${fid}\r\n`;

    if (name && name.length > 0) {
      body = body + `--${boundary}\r\n`;
      body = body + `Content-Disposition: form-data; name="name"\r\n\r\n`;
      body = body + `${name}\r\n`;
    }

    if (email && email.length > 0) {
      body = body + `--${boundary}\r\n`;
      body = body + `Content-Disposition: form-data; name="email"\r\n\r\n`;
      body = body + `${email}\r\n`;
    }

    if (title && title.length > 0) {
      body = body + `--${boundary}\r\n`;
      body = body + `Content-Disposition: form-data; name="title"\r\n\r\n`;
      body = body + `${title}\r\n`;
    }

    if (content && content.length > 0) {
      body = body + `--${boundary}\r\n`;
      body = body + `Content-Disposition: form-data; name="content"\r\n\r\n`;
      body = body + `${content}\r\n`;
    }

    if (water && water.length > 0) {
      body = body + `--${boundary}\r\n`;
      body = body + `Content-Disposition: form-data; name="water"\r\n\r\n`;
      body = body + `${water}\r\n`;
    }

    body = body + `--${boundary}--\r\n`;

    return await this.postMultipart(url, body, boundary, cookieHeader);
  }

  async postReply(
    resto: string,
    content: string,
    name?: string,
    email?: string,
    title?: string,
    water?: string,
    imageFilePath?: string,
  ): Promise<string> {
    if (!(await this.hasCookie())) {
      throw new RequiresLoginException();
    }

    await this.waitForRateLimit();
    const cookieHeader: string = await this.getCookieHeader();
    const url = `${this.baseUrl}Home/Forum/doReplyThread.html`;

    console.info(`[AnoBBS] Posting reply to thread ${resto}`);

    if (imageFilePath && imageFilePath.length > 0) {
      return await this.postMultipartWithImage(
        url,
        resto,
        content,
        name,
        email,
        title,
        water,
        imageFilePath,
        cookieHeader,
      );
    }

    const boundary: string = `----WebKitFormBoundary${Date.now().toString(16)}`;
    let body: string = "";

    body = body + `--${boundary}\r\n`;
    body = body + `Content-Disposition: form-data; name="resto"\r\n\r\n`;
    body = body + `${resto}\r\n`;

    if (name && name.length > 0) {
      body = body + `--${boundary}\r\n`;
      body = body + `Content-Disposition: form-data; name="name"\r\n\r\n`;
      body = body + `${name}\r\n`;
    }

    if (email && email.length > 0) {
      body = body + `--${boundary}\r\n`;
      body = body + `Content-Disposition: form-data; name="email"\r\n\r\n`;
      body = body + `${email}\r\n`;
    }

    if (title && title.length > 0) {
      body = body + `--${boundary}\r\n`;
      body = body + `Content-Disposition: form-data; name="title"\r\n\r\n`;
      body = body + `${title}\r\n`;
    }

    if (content && content.length > 0) {
      body = body + `--${boundary}\r\n`;
      body = body + `Content-Disposition: form-data; name="content"\r\n\r\n`;
      body = body + `${content}\r\n`;
    }

    if (water && water.length > 0) {
      body = body + `--${boundary}\r\n`;
      body = body + `Content-Disposition: form-data; name="water"\r\n\r\n`;
      body = body + `${water}\r\n`;
    }

    body = body + `--${boundary}--\r\n`;

    return await this.postMultipart(url, body, boundary, cookieHeader);
  }

  private async postMultipartWithImage(
    url: string,
    resto: string,
    content: string,
    name?: string,
    email?: string,
    title?: string,
    water?: string,
    imageFilePath?: string,
    cookieHeader?: string,
  ): Promise<string> {
    const httpRequest = http.createHttp();
    try {
      console.info(`[AnoBBS] ========== POST REQUEST WITH IMAGE START ==========`);
      console.info(`[AnoBBS] Request URL: ${url}`);
      console.info(`[AnoBBS] Image path: ${imageFilePath}`);

      const formDataList: http.MultiFormData[] = [];

      formDataList.push({
        name: "resto",
        contentType: "text/plain",
        data: resto,
      });

      if (name && name.length > 0) {
        formDataList.push({
          name: "name",
          contentType: "text/plain",
          data: name,
        });
      }

      if (email && email.length > 0) {
        formDataList.push({
          name: "email",
          contentType: "text/plain",
          data: email,
        });
      }

      if (title && title.length > 0) {
        formDataList.push({
          name: "title",
          contentType: "text/plain",
          data: title,
        });
      }

      if (content && content.length > 0) {
        formDataList.push({
          name: "content",
          contentType: "text/plain",
          data: content,
        });
      }

      if (water && water.length > 0) {
        formDataList.push({
          name: "water",
          contentType: "text/plain",
          data: water,
        });
      }

      if (imageFilePath && imageFilePath.length > 0) {
        const fileName: string = imageFilePath.split("/").pop() || "image.jpg";
        console.info(
          `[AnoBBS] Adding image to formData: name=image, filePath=${imageFilePath}, fileName=${fileName}`,
        );
        formDataList.push({
          name: "image",
          contentType: "image/jpeg",
          filePath: imageFilePath,
          remoteFileName: fileName,
        });
      } else {
        console.info(`[AnoBBS] No image to upload, imageFilePath is empty`);
      }

      console.info(`[AnoBBS] FormData list count: ${formDataList.length}`);
      formDataList.forEach((item, index) => {
        console.info(`[AnoBBS] FormData[${index}]: name=${item.name}, type=${item.contentType}`);
      });

      const headerOptions: ESObject = {
        "User-Agent": this.config.userAgent,
        Accept: "*/*",
        "Accept-Language": "zh-cn",
        Connection: "keep-alive",
        Cookie: cookieHeader,
      };

      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: headerOptions,
        multiFormDataList: formDataList,
        connectTimeout: 60000,
        readTimeout: 60000,
      });

      console.info(`[AnoBBS] Response status: ${response.responseCode}`);

      const responseBody: string = response.result as string;
      console.info(`[AnoBBS] Response body length: ${responseBody.length}`);
      console.info(`[AnoBBS] Response body: ${responseBody}`);
      console.info(`[AnoBBS] ========== POST REQUEST WITH IMAGE END ==========`);

      if (
        responseBody.includes("错误") ||
        responseBody.includes("error") ||
        responseBody.includes("失败")
      ) {
        console.error(`[AnoBBS] Response contains error message`);
        throw new ApiException(responseBody);
      }

      if (response.responseCode === 200 || response.responseCode === 302) {
        const redirectLocation: string = response.header["location"] as string;
        if (redirectLocation && redirectLocation.length > 0) {
          const match: RegExpMatchArray | null = redirectLocation.match(/\/t\/(\d+)/);
          if (match && match.length > 1) {
            return match[1];
          }
        }

        const idMatch: RegExpMatchArray | null = responseBody.match(/No\.(\d+)/);
        if (idMatch && idMatch.length > 1) {
          return idMatch[1];
        }

        return "success";
      } else if (response.responseCode === 403) {
        throw new RequiresLoginException();
      } else {
        throw new ApiException(`HTTP error: ${response.responseCode}`);
      }
    } catch (error) {
      console.error(`[AnoBBS] POST request with image error: ${error}`);
      if (error instanceof RequiresLoginException) {
        throw new RequiresLoginException();
      }
      if (error instanceof ApiException) {
        throw new ApiException(error.rawText);
      }
      throw new NetworkException(`Network error: ${JSON.stringify(error)}`);
    } finally {
      httpRequest.destroy();
    }
  }

  private async postMultipart(
    url: string,
    body: string,
    boundary: string,
    cookieHeader: string,
  ): Promise<string> {
    const httpRequest = http.createHttp();
    try {
      console.info(`[AnoBBS] ========== POST REQUEST START ==========`);
      console.info(`[AnoBBS] Request URL: ${url}`);

      const headerOptions: ESObject = {
        "User-Agent": this.config.userAgent,
        Accept: "*/*",
        "Accept-Language": "zh-cn",
        "Content-Type": `multipart/form-data; boundary=${boundary}`,
        Connection: "keep-alive",
        Cookie: cookieHeader,
      };

      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: headerOptions,
        extraData: body,
        connectTimeout: 20000,
        readTimeout: 20000,
      });

      console.info(`[AnoBBS] Response status: ${response.responseCode}`);

      const responseBody: string = response.result as string;
      console.info(`[AnoBBS] Response body: ${responseBody.substring(0, 500)}`);
      console.info(`[AnoBBS] ========== POST REQUEST END ==========`);

      if (response.responseCode === 200) {
        const successMatch: RegExpMatchArray | null = responseBody.match(
          /<p class="success"[^>]*>([^<]+)<\/p>/,
        );
        if (successMatch !== null && successMatch.length > 1) {
          const successMsg: string = successMatch[1];
          console.info(`[AnoBBS] Post success: ${successMsg}`);
          const idMatch: RegExpMatchArray | null = responseBody.match(/t\/(\d+)/);
          if (idMatch !== null && idMatch.length > 1) {
            return idMatch[1];
          }
          return "";
        }

        const errorMatch: RegExpMatchArray | null = responseBody.match(
          /<p class="error"[^>]*>([^<]+)<\/p>/,
        );
        if (errorMatch !== null && errorMatch.length > 1) {
          const errorMsg: string = errorMatch[1];
          console.error(`[AnoBBS] Post failed: ${errorMsg}`);
          throw new ApiException(errorMsg);
        }

        if (responseBody.indexOf("成功") !== -1) {
          console.info(`[AnoBBS] Post appears successful`);
          const idMatch: RegExpMatchArray | null = responseBody.match(/t\/(\d+)/);
          if (idMatch !== null && idMatch.length > 1) {
            return idMatch[1];
          }
          return "";
        }

        throw new NetworkException(`发串失败: 未知响应`);
      }

      throw new NetworkException(`发串失败: HTTP ${response.responseCode}`);
    } catch (error) {
      if (error instanceof RequiresLoginException) {
        throw new RequiresLoginException();
      }
      if (error instanceof ApiException) {
        throw new ApiException(error.rawText);
      }

      const err = error as Error;
      const errMsg: string = err.message ? err.message : "Unknown error";
      console.error(`[AnoBBS] Post error: ${errMsg}`);
      throw new NetworkException(`发串失败: ${errMsg}`);
    } finally {
      httpRequest.destroy();
    }
  }

  private async waitForRateLimit(): Promise<void> {
    const now = Date.now();
    const elapsed = now - this.lastRequestTime;
    if (elapsed < this.minRequestInterval) {
      const waitTime = this.minRequestInterval - elapsed;
      await new Promise<void>((resolve) => {
        setTimeout(() => {
          resolve();
        }, waitTime);
      });
    }
    this.lastRequestTime = Date.now();
  }

  private buildUrl(endpoint: string, params: ESObject): string {
    let url = `${this.baseUrl}${endpoint}`;
    const keys: string[] = Object.keys(params);
    if (keys.length > 0) {
      url = url + "?";
      for (let i: number = 0; i < keys.length; i++) {
        if (i > 0) {
          url = url + "&";
        }
        url = url + keys[i] + "=" + encodeURIComponent(params[keys[i]] as string);
      }
    }
    return url;
  }

  private async getJson(endpoint: string, params: ESObject): Promise<ESObject> {
    const httpRequest = http.createHttp();
    try {
      const cookieHeader: string = await this.getCookieHeader();
      const url = this.buildUrl(endpoint, params);
      console.info(`[AnoBBS] ========== REQUEST START ==========`);
      console.info(`[AnoBBS] Request URL: ${url}`);
      console.info(`[AnoBBS] Cookie header length: ${cookieHeader.length}`);

      const headerOptions: ESObject = {
        "User-Agent": this.config.userAgent,
        Accept: "application/json",
        "Accept-Language": "zh-cn",
        "Content-Type": "application/json; charset=utf-8",
        Connection: "keep-alive",
      };
      if (cookieHeader.length > 0) {
        headerOptions["Cookie"] = cookieHeader;
      }

      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: headerOptions,
        connectTimeout: 20000,
        readTimeout: 20000,
      });

      console.info(`[AnoBBS] ========== RESPONSE START ==========`);
      console.info(`[AnoBBS] Response status: ${response.responseCode}`);
      console.info(`[AnoBBS] Response headers: ${JSON.stringify(response.header)}`);

      const responseBody: string = response.result as string;
      console.info(`[AnoBBS] Response body length: ${responseBody.length}`);
      console.info(`[AnoBBS] Response body (first 500 chars): ${responseBody.substring(0, 500)}`);

      const data: ESObject = JSON.parse(responseBody) as ESObject;
      console.info(`[AnoBBS] Response data.success: ${data.success}`);
      console.info(`[AnoBBS] Response data.error: ${data.error ? data.error : "null"}`);
      console.info(`[AnoBBS] ========== RESPONSE END ==========`);

      if (data.success === false && typeof data.error === "string") {
        const errorMsg: string = data.error as string;
        console.error(`[AnoBBS] API returned error: ${errorMsg}`);
        if (this.isRequiresLoginError(errorMsg)) {
          console.warn(`[AnoBBS] Requires login: ${errorMsg}`);
          throw new RequiresLoginException();
        }
        throw new ApiException(errorMsg);
      }

      return data;
    } catch (error) {
      if (error instanceof RequiresLoginException) {
        throw new RequiresLoginException();
      }
      if (error instanceof ApiException) {
        throw new ApiException(error.rawText);
      }
      if (error instanceof GatekeptException) {
        throw new GatekeptException(error.params);
      }

      const err = error as Error;
      const errMsg: string = err.message ? err.message : "Unknown error";
      console.error(`[AnoBBS] HTTP error: ${errMsg}`);
      throw new NetworkException(`请求失败: ${errMsg}`);
    } finally {
      httpRequest.destroy();
    }
  }
}
