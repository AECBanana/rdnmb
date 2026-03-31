export class RequiresLoginException extends Error {
  constructor(message: string = "") {
    super(`操作需要登录但未登陆: ${message}`);
  }
}

export interface GatekeptExceptionParams {
  message?: string;
  context?: string;
  currentPageNumber?: number;
  lastAccessiblePostId?: number;
}

export class GatekeptException extends Error {
  constructor(params: GatekeptExceptionParams) {
    let fullMessage = "检测到卡页";
    const extraMessages: string[] = [];
    if (params.context) {
      extraMessages.push("上下文: " + params.context);
    }
    if (params.currentPageNumber != undefined) {
      extraMessages.push("发生卡页现象的页数: " + params.currentPageNumber);
    }
    if (params.lastAccessiblePostId != undefined) {
      extraMessages.push("最后可访问到的回应/主串的串号: " + params.lastAccessiblePostId);
    }
    if (extraMessages.length > 0) {
      fullMessage += (' (' + extraMessages.join(', ') + ')');
    }
    if (params.message) {
      fullMessage += ': ' + params.message;
    }
    super(fullMessage);
  }
}

export class ApiException extends Error {
  rawText: string;

  constructor(rawText: string) {
    super(`API 异常: ${rawText}`);
    this.rawText = rawText;
  }
}

export class ThreadNotExistsException extends ApiException {
  constructor(rawText: string) {
    super(rawText);
  }
}

export class NetworkException extends Error {
  constructor(message: string = "网络请求失败") {
    super(message);
  }
}

export function throwApiException(rawText: string): void {
  if (rawText === '该主题不存在') {
    throw new ThreadNotExistsException(rawText);
  } else {
    throw new ApiException(rawText);
  }
}
