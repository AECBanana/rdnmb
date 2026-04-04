import { common } from "@kit.AbilityKit";
import { ImageCacheManager } from "../utils/ImageCacheManager";
import { CookieManager } from "../utils/CookieManager";
import { Cookie } from "../models/Cookie";
import { scanBarcode, scanCore } from "@kit.ScanKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { webview } from "@kit.ArkWeb";
import bundleManager from "@ohos.bundle.bundleManager";

@CustomDialog
struct ManualAddCookieDialog {
  controller: CustomDialogController = new CustomDialogController({
    builder: () => {},
    customStyle: true,
  });
  onConfirm?: (cookieHash: string, cookieName: string) => void;
  @State inputValue: string = "";

  build() {
    Column() {
      Text("手动添加饼干")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 12 })
      Text("请输入二维码内容，例如：")
        .fontSize(12)
        .fontColor($r("app.color.text_secondary"))
        .width("100%")
        .margin({ bottom: 4 })
      Text('{"cookie":"...","name":"..."}')
        .fontSize(11)
        .fontColor($r("app.color.text_secondary"))
        .width("100%")
        .margin({ bottom: 16 })
      TextArea({ text: this.inputValue, placeholder: "粘贴二维码内容..." })
        .width("100%")
        .height(120)
        .margin({ bottom: 16 })
        .onChange((value: string) => {
          this.inputValue = value;
        })
      Row() {
        Button("取消")
          .width(100)
          .backgroundColor("#f0f0f0")
          .fontColor($r("app.color.text_primary"))
          .onClick(() => {
            this.controller.close();
          })
        Blank()
        Button("添加")
          .width(100)
          .onClick(() => {
            if (this.inputValue.trim().length === 0) {
              try {
                this.getUIContext().getPromptAction().showToast({ message: "请输入内容" });
              } catch (error) {
                // TODO: Implement error handling.
              }
              return;
            }
            const parsed: ManualAddCookieDialog.ParsedCookie = ManualAddCookieDialog.parseQRContent(
              this.inputValue.trim(),
            );
            if (parsed.cookieHash.length > 0) {
              if (this.onConfirm) {
                this.onConfirm(parsed.cookieHash, parsed.cookieName);
              }
              this.controller.close();
            } else {
              try {
                this.getUIContext()
                  .getPromptAction()
                  .showToast({ message: '请输入有效的饼干信息 es:{"cookie":"","name":""}' });
              } catch (error) {}
            }
          })
      }.width("100%")
    }
    .width("100%")
    .padding({ left: 8, right: 8, top: 44, bottom: 8 });
  }

  static parseQRContent(qrContent: string): ManualAddCookieDialog.ParsedCookie {
    let cookieHash: string = "";
    let cookieName: string = "";

    console.info(`[ManualAddCookieDialog] Parsing QR content: ${qrContent}`);

    try {
      const json: ESObject = JSON.parse(qrContent) as ESObject;
      if (json.cookie !== undefined && typeof json.cookie === "string") {
        cookieHash = json.cookie as string;
      }
      if (json.name !== undefined && typeof json.name === "string") {
        cookieName = json.name as string;
      }
    } catch (e) {
      console.warn(`[ManualAddCookieDialog] Content is not JSON, trying fallback parse`);
      if (qrContent.includes("userhash=")) {
        const hashMatch: RegExpMatchArray | null = qrContent.match(/userhash=([^&\s]+)/);
        if (hashMatch && hashMatch.length > 1) {
          cookieHash = hashMatch[1];
        }
      } else if (qrContent.length > 0 && qrContent.length < 100) {
        cookieHash = qrContent;
      }
    }

    console.info(
      `[ManualAddCookieDialog] Parsed cookieHash: ${cookieHash}, cookieName: ${cookieName}`,
    );
    return { cookieHash, cookieName };
  }
}

namespace ManualAddCookieDialog {
  export interface ParsedCookie {
    cookieHash: string;
    cookieName: string;
  }
}

@Entry
@Component
struct SettingsPage {
  @State cacheSize: string = "计算中...";
  @State cookies: Cookie[] = [];
  @State selectedCookieHash: string = "";
  @State showWebSheet: boolean = false;
  @State appVersion: string = "";
  @State initialCookieHash: string = "";

  private imageCacheManager: ImageCacheManager = ImageCacheManager.getInstance();
  private cookieManager: CookieManager = CookieManager.getInstance();
  private webController: webview.WebviewController = new webview.WebviewController();
  private manualAddDialogController: CustomDialogController | null = null;
  private webCookieCache: Map<string, string> = new Map<string, string>();

  aboutToAppear() {
    this.calculateCacheSize();
    this.loadCookies();
  }

  aboutToDisappear(): void {
    try {
      this.webController.stop();
    } catch (error) {
      // TODO: Implement error handling.
    }
  }

  async getAppVersion() {
    try {
      const bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT;
      const bundleInfo = await bundleManager.getBundleInfo("com.ohos.cookies", bundleFlags);

      const version = bundleInfo.versionName;
    } catch (error) {
      console.error(error);
    }
  }

  async calculateCacheSize() {
    try {
      const sizeBytes: number = await this.imageCacheManager.getCacheSize();
      const formattedSize: string = this.imageCacheManager.formatSize(sizeBytes);
      this.cacheSize = `约 ${formattedSize}`;
    } catch (error) {
      console.error(`[SettingsPage] Calculate cache size failed: ${error}`);
      this.cacheSize = "约 0 MB";
    }
  }

  async loadCookies() {
    await this.cookieManager.waitForInit();
    this.cookies = this.cookieManager.getCookies();
    this.selectedCookieHash = this.cookieManager.getSelectedCookieHash();
  }

  async clearImageCache() {
    await this.imageCacheManager.clearCache();
    await this.calculateCacheSize();
    try {
      this.getUIContext().getPromptAction().showToast({ message: "缓存已清空..." });
    } catch (error) {
      // TODO: Implement error handling.
    }
  }

  async addCookie(hash: string, cookieName: string) {
    console.info(`[SettingsPage] addCookie called, hash length: ${hash.length}`);
    console.info(`[SettingsPage] hash bytes: ${this.stringToHexBytes(hash)}`);
    console.info(`[SettingsPage] hash contains null: ${hash.indexOf("\x00") !== -1}`);
    const finalDisplayName: string = cookieName.length > 0 ? cookieName : "匿名";
    await this.cookieManager.addCookie(
      hash,
      cookieName.length > 0 ? cookieName : "user",
      finalDisplayName,
    );
    this.loadCookies();
    try {
      this.getUIContext().getPromptAction().showToast({ message: "饼干添加成功" });
    } catch (error) {
      // TODO: Implement error handling.
    }
  }

  async deleteCookie(cookieHash: string) {
    await this.cookieManager.deleteCookie(cookieHash);
    this.loadCookies();
    try {
      this.getUIContext().getPromptAction().showToast({ message: "饼干已删除" });
    } catch (error) {
      // TODO: Implement error handling.
    }
  }

  async selectCookie(cookieHash: string) {
    await this.cookieManager.setSelectedCookie(cookieHash);
    this.selectedCookieHash = cookieHash;
    try {
      this.getUIContext().getPromptAction().showToast({ message: "已切换饼干" });
    } catch (error) {
      // TODO: Implement error handling.
    }
  }

  showManualAddDialog() {
    this.manualAddDialogController = new CustomDialogController({
      builder: ManualAddCookieDialog({
        onConfirm: (cookieHash: string, cookieName: string) => {
          this.addCookie(cookieHash, cookieName);
        },
      }),
      customStyle: true,
      alignment: DialogAlignment.Center,
      backgroundColor: $r("app.color.card_background"),
    });
    this.manualAddDialogController.open();
  }

  async scanQRCodeAndAdd() {
    try {
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.ALL],
        enableMultiMode: false,
        enableAlbum: true,
      };

      scanBarcode
        .startScanForResult(getContext(this) as common.UIAbilityContext, options)
        .then((result: scanBarcode.ScanResult) => {
          const originalValue: string = result.originalValue;
          this.parseQRCodeResult(originalValue);
        })
        .catch((error: BusinessError) => {
          console.error(`Scan failed: ${error.message}`);
          this.getUIContext().getPromptAction().showToast({ message: "扫码取消或失败" });
        });
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`Start scan failed: ${err.message}`);
      this.getUIContext().getPromptAction().showToast({ message: "扫码取消或失败" });
    }
  }

  parseQRCodeResult(qrContent: string) {
    console.info(`[SettingsPage] QR content raw: ${qrContent}`);
    console.info(`[SettingsPage] QR content length: ${qrContent.length}`);
    let cookieHash: string = "";
    let cookieName: string = "";

    try {
      const json: ESObject = JSON.parse(qrContent) as ESObject;
      console.info(`[SettingsPage] Parsed JSON, cookie field: ${json.cookie}`);
      if (json.cookie !== undefined && typeof json.cookie === "string") {
        cookieHash = json.cookie as string;
      }
      if (json.name !== undefined && typeof json.name === "string") {
        cookieName = json.name as string;
      }
    } catch (e) {
      console.warn(`[SettingsPage] QR content is not JSON, trying fallback parse`);
      if (qrContent.includes("userhash=")) {
        const hashMatch: RegExpMatchArray | null = qrContent.match(/userhash=([^&\s]+)/);
        if (hashMatch && hashMatch.length > 1) {
          cookieHash = hashMatch[1];
        }
      } else if (qrContent.length > 0 && qrContent.length < 100) {
        cookieHash = qrContent;
      }
    }

    console.info(
      `[SettingsPage] Extracted cookieHash: "${cookieHash}", length: ${cookieHash.length}`,
    );
    console.info(`[SettingsPage] cookieHash bytes: ${this.stringToHexBytes(cookieHash)}`);
    if (cookieHash.length > 0) {
      this.addCookie(cookieHash, cookieName);
    } else {
      try {
        this.getUIContext().getPromptAction().showToast({ message: "未识别到有效的饼干信息" });
      } catch (error) {
        // TODO: Implement error handling.
      }
    }
  }

  stringToHexBytes(str: string): string {
    let result: string = "";
    for (let i: number = 0; i < str.length; i++) {
      const code: number = str.charCodeAt(i);
      result += code.toString(16).toUpperCase().padStart(2, "0") + " ";
    }
    return result;
  }

  @Builder
  cacheHeader() {
    Text("缓存")
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor($r("app.color.text_secondary"))
      .width("100%")
      .padding({ left: 16, top: 8, bottom: 8 });
  }

  @Builder
  webDialogContent() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r("sys.symbol.xmark"))
            .fontSize(20)
            .fontColor([$r("app.color.text_primary")])
        }
        .backgroundColor("transparent")
        .width(44)
        .height(44)
        .onClick(() => {
          this.showWebSheet = false;
        })
        Text("获取饼干")
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r("app.color.text_primary"))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank().width(44)
      }
      .width("100%")
      .padding({ left: 8, right: 8, top: 44, bottom: 8 })
      .backgroundColor($r("app.color.card_background"))
      Web({
        src: "https://www.nmbxd1.com/Member/User/Index/login.html",
        controller: this.webController,
      })
        .width("100%")
        .layoutWeight(1)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .cacheMode(CacheMode.Default)
        .onPageEnd((event) => {
          const url: string = event?.url ?? "";
          console.info(`[SettingsPage] Page end URL: ${url}`);
          this.tryExtractCookieFromWeb(url);
        })
    }
    .width("100%")
    .height("100%")
    .backgroundColor($r("app.color.background"));
  }

  tryExtractCookieFromWeb(currentUrl: string) {
    const isCookieListPage: boolean = currentUrl.includes("Cookie/index.html");
    const isSwitchPage: boolean = currentUrl.includes("Cookie/switchTo/id/");

    if (isCookieListPage) {
      this.cacheAllCookiesFromPage();
    }

    if (isSwitchPage) {
      const idMatch: RegExpMatchArray | null = currentUrl.match(/switchTo\/id\/(\d+)\.html/);
      if (idMatch && idMatch.length > 1) {
        const cookieId: string = idMatch[1];
        console.info(`[SettingsPage] Switching to cookie ID: ${cookieId}`);
        this.webController
          .runJavaScript("document.cookie")
          .then((result: string) => {
            console.info(`[SettingsPage] Web cookies: ${result}`);
            let cookieHash: string = "";
            if (result.includes("userhash=")) {
              const hashMatch: RegExpMatchArray | null = result.match(/userhash=([^;]+)/);
              if (hashMatch && hashMatch.length > 1) {
                let rawHash: string = hashMatch[1];
                console.info(
                  `[SettingsPage] Raw hash from regex: "${rawHash}", length: ${rawHash.length}`,
                );
                console.info(`[SettingsPage] Raw hash bytes: ${this.stringToHexBytes(rawHash)}`);
                try {
                  cookieHash = decodeURIComponent(rawHash);
                } catch (e) {
                  cookieHash = rawHash;
                }
                cookieHash = cookieHash.replace(/["'\x00]/g, "").trim();
              }
            }
            console.info(`[SettingsPage] Decoded cookieHash length: ${cookieHash.length}`);
            console.info(
              `[SettingsPage] Decoded cookieHash bytes: ${this.stringToHexBytes(cookieHash)}`,
            );
            if (cookieHash.length > 0) {
              this.extractCookieNameById(cookieHash, cookieId);
            }
          })
          .catch(() => {});
      }
      return;
    }

    this.webController
      .runJavaScript("document.cookie")
      .then((result: string) => {
        console.info(`[SettingsPage] Web cookies: ${result}`);
        let cookieHash: string = "";
        if (result.includes("userhash=")) {
          const hashMatch: RegExpMatchArray | null = result.match(/userhash=([^;]+)/);
          if (hashMatch && hashMatch.length > 1) {
            try {
              cookieHash = decodeURIComponent(hashMatch[1].trim());
            } catch (e) {
              cookieHash = hashMatch[1].trim();
            }
          }
        }

        if (this.initialCookieHash === "") {
          this.initialCookieHash = cookieHash;
          console.info(`[SettingsPage] Initial cookie recorded: ${this.initialCookieHash}`);
        } else if (cookieHash !== this.initialCookieHash && cookieHash.length > 0) {
          console.info(
            `[SettingsPage] Cookie changed from "${this.initialCookieHash}" to "${cookieHash}"`,
          );
          this.extractCookieName(cookieHash, isCookieListPage);
        }
      })
      .catch(() => {
        // TODO: Implement error handling.
      });
  }

  extractCookieNameById(cookieHash: string, cookieId: string) {
    console.info(
      `[SettingsPage] Looking for ID ${cookieId} in cache (size: ${this.webCookieCache.size})`,
    );
    const cachedName: string | undefined = this.webCookieCache.get(cookieId);
    if (cachedName !== undefined) {
      console.info(`[SettingsPage] Found cached name for ID ${cookieId}: ${cachedName}`);
      this.addCookie(cookieHash, cachedName);
      this.showWebSheet = false;
      return;
    }
    console.info(`[SettingsPage] No cached name for ID ${cookieId}, using default`);
    this.addCookie(cookieHash, "匿名");
    this.showWebSheet = false;
  }

  cacheAllCookiesFromPage() {
    const jsCode: string = `
      (function() {
        var result = [];
        var tables = document.querySelectorAll('table');
        for (var t = 0; t < tables.length; t++) {
          var tbody = tables[t].querySelector('tbody');
          var rows = tbody ? tbody.querySelectorAll('tr') : tables[t].querySelectorAll('tr');
          for (var r = 0; r < rows.length; r++) {
            var cells = rows[r].querySelectorAll('td');
            if (cells.length >= 3) {
              var idCell = cells[1].innerText.trim();
              var nameLink = cells[2].querySelector('a');
              var nameCell = nameLink ? nameLink.innerText.trim() : cells[2].innerText.trim();
              if (idCell && nameCell) {
                result.push(idCell + ':::' + nameCell);
              }
            }
          }
        }
        return result.join('|||');
      })()
    `;
    this.webController
      .runJavaScript(jsCode)
      .then((result: string) => {
        console.info(`[SettingsPage] Cache result: ${result}`);
        if (result && result.length > 0) {
          const items: string[] = result.split("|||");
          for (const item of items) {
            const parts: string[] = item.split(":::");
            if (parts.length === 2) {
              const id: string = parts[0].replace(/["']/g, "").trim();
              const name: string = parts[1].replace(/["']/g, "").trim();
              this.webCookieCache.set(id, name);
              console.info(`[SettingsPage] Cached cookie: ${id} -> ${name}`);
            }
          }
          console.info(`[SettingsPage] Total cached cookies: ${this.webCookieCache.size}`);
        }
      })
      .catch(() => {});
  }

  extractCookieName(cookieHash: string, isCookiePage: boolean) {
    const cachedName: string | undefined = this.webCookieCache.get(cookieHash);
    if (cachedName !== undefined) {
      console.info(`[SettingsPage] Found cached name for ${cookieHash}: ${cachedName}`);
      this.addCookie(cookieHash, cachedName);
      this.showWebSheet = false;
      return;
    }

    if (!isCookiePage) {
      console.info(`[SettingsPage] Not on cookie page and no cache, using default name`);
      this.addCookie(cookieHash, "匿名");
      this.showWebSheet = false;
      return;
    }

    const jsCode: string = `
      (function() {
        var tables = document.querySelectorAll('table');
        for (var t = 0; t < tables.length; t++) {
          var rows = tables[t].querySelectorAll('tr');
          for (var r = 0; r < rows.length; r++) {
            var cells = rows[r].querySelectorAll('td');
            if (cells.length >= 2) {
              var idCell = cells[0].innerText.trim();
              var nameCell = cells[1].innerText.trim();
              if (idCell === '${cookieHash}' || idCell.indexOf('${cookieHash}') === 0) {
                return nameCell || '匿名';
              }
            }
          }
        }
        return '匿名';
      })()
    `;
    this.webController
      .runJavaScript(jsCode)
      .then((cookieName: string) => {
        console.info(`[SettingsPage] Extracted userhash: ${cookieHash}, name: ${cookieName}`);
        this.addCookie(cookieHash, cookieName);
        this.showWebSheet = false;
      })
      .catch(() => {
        console.info(`[SettingsPage] Extracted userhash: ${cookieHash}, using default name`);
        this.addCookie(cookieHash, "匿名");
        this.showWebSheet = false;
      });
  }

  @Builder
  cookieHeader() {
    Column() {
      Row() {
        Text("饼干")
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r("app.color.text_secondary"))
      }
      .width("100%")
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    };
    Row() {
      Button("󰗱 获取饼干")
        .fontSize(16)
        .fontColor($r("app.color.primary"))
        .backgroundColor($r("app.color.card_background"))
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.initialCookieHash = "";
          this.showWebSheet = true;
        })
      Blank()
      Button("󰁦 手动")
        .fontSize(16)
        .fontColor($r("app.color.primary"))
        .backgroundColor($r("app.color.card_background"))
        .padding({ left: 16, right: 16 })
        .margin({ right: 8 })
        .onClick(() => {
          this.showManualAddDialog();
        })
      Button("󰄨 扫码")
        .fontSize(16)
        .fontColor($r("app.color.primary"))
        .backgroundColor($r("app.color.card_background"))
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.scanQRCodeAndAdd();
        })
    }
    .width("100%")
    .margin({ bottom: 16 })
    .justifyContent(FlexAlign.End);
  }

  @Builder
  aboutHeader() {
    Text("关于")
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor($r("app.color.text_secondary"))
      .width("100%")
      .padding({ left: 16, top: 8, bottom: 8 });
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r("sys.symbol.arrow_left"))
        }
        .backgroundColor("transparent")
        .width(48)
        .height(48)
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })
        Text("设置")
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r("app.color.text_primary"))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
          .margin({ left: 8 })
      }
      .width("100%")
      .padding({ left: 8, right: 8, top: 44, bottom: 8 })
      List() {
        ListItemGroup({ header: this.cookieHeader }) {
          if (this.cookies.length === 0) {
            ListItem() {
              Row() {
                Text("暂无饼干，点击上方按钮添加")
                  .fontSize(14)
                  .fontColor($r("app.color.text_secondary"))
              }
              .width("100%")
              .backgroundColor($r("app.color.card_background"))
              .padding(16)
              .borderRadius(16)
              .justifyContent(FlexAlign.Center)
            };
          } else {
            ForEach(this.cookies, (cookie: Cookie) => {
              ListItem() {
                Row() {
                  Column() {
                    Row() {
                      Text(cookie.cookieDisplayName)
                        .fontSize(16)
                        .fontColor($r("app.color.text_primary"))
                      if (this.selectedCookieHash === cookie.cookieHash) {
                        Text("使用中")
                          .fontSize(10)
                          .fontColor(Color.White)
                          .backgroundColor($r("app.color.primary"))
                          .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                          .borderRadius(4)
                          .margin({ left: 8 });
                      }
                    }
                    Text(cookie.cookieHash.substring(0, 8) + "...")
                      .fontSize(12)
                      .fontColor($r("app.color.text_secondary"))
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  if (this.selectedCookieHash !== cookie.cookieHash) {
                    Button("使用")
                      .fontSize(12)
                      .fontColor($r("app.color.primary"))
                      .backgroundColor("transparent")
                      .margin({ right: 8 })
                      .onClick(() => {
                        this.selectCookie(cookie.cookieHash);
                      });
                  }
                  Button("删除")
                    .fontSize(12)
                    .fontColor("#ff6b6b")
                    .backgroundColor("transparent")
                    .onClick(() => {
                      this.deleteCookie(cookie.cookieHash);
                    })
                }
                .margin({ bottom: 16 })
                .width("100%")
                .backgroundColor($r("app.color.card_background"))
                .borderRadius(16)
                .padding(16)
              };
            });
          }
        }
        ListItemGroup({ header: this.cacheHeader }) {
          ListItem() {
            Row() {
              Column() {
                Text("缓存")
                  .fontSize(16)
                  .fontColor($r("app.color.text_primary"))
                Text(this.cacheSize)
                  .fontSize(12)
                  .fontColor($r("app.color.text_secondary"))
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Button({ type: ButtonType.Circle }) {
                SymbolGlyph($r("sys.symbol.eraser_line"))
                  .fontSize(14)
                  .fontColor([$r("app.color.primary")])
              }
              .backgroundColor("transparent")
              .width(48)
              .height(48)
              .onClick(() => {
                this.clearImageCache();
              })
            }
            .backgroundColor($r("app.color.card_background"))
            .borderRadius(16)
            .shadow({ radius: 4, color: $r("app.color.card_shadow") })
            .width("100%")
            .padding(16)
          }
        }
        ListItemGroup({ header: this.aboutHeader }) {
          ListItem() {
            Row() {
              Text("版本")
                .fontSize(16)
                .fontColor($r("app.color.text_primary"))
                .layoutWeight(1)
              Text("1")
                .fontSize(14)
                .fontColor($r("app.color.text_secondary"))
            }
            .width("100%")
            .padding(16)
          }
          ListItem() {
            Row() {
              Text("开发者")
                .fontSize(16)
                .fontColor($r("app.color.text_primary"))
                .layoutWeight(1)
              Text("AeCw")
                .fontSize(14)
                .fontColor($r("app.color.text_secondary"))
            }
            .width("100%")
            .padding(16)
          }
        }
      }
      .width("100%")
      .padding({ left: 16, right: 16 })
      .height("auto")
      .layoutWeight(1)
      .chainAnimation(true)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .backgroundColor($r("app.color.background"))
      .divider({ strokeWidth: 1, color: $r("app.color.divider") })
    }
    .width("100%")
    .height("100%")
    .backgroundColor($r("app.color.background"))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .bindContentCover(this.showWebSheet, this.webDialogContent(), {
      modalTransition: ModalTransition.DEFAULT,
      onDisappear: () => {
        this.showWebSheet = false;
      },
    });
  }
}
