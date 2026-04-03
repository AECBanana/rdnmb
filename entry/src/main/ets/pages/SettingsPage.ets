import { common } from "@kit.AbilityKit";
import { ImageCacheManager } from "../utils/ImageCacheManager";
import { CookieManager } from "../utils/CookieManager";
import { Cookie } from "../models/Cookie";
import { scanBarcode, scanCore } from "@kit.ScanKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { webview } from "@kit.ArkWeb";

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

  private imageCacheManager: ImageCacheManager = ImageCacheManager.getInstance();
  private cookieManager: CookieManager = CookieManager.getInstance();
  private webController: webview.WebviewController = new webview.WebviewController();
  private manualAddDialogController: CustomDialogController | null = null;

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

  calculateCacheSize() {
    this.cacheSize = "约 0 MB";
  }

  async loadCookies() {
    await this.cookieManager.waitForInit();
    this.cookies = this.cookieManager.getCookies();
    this.selectedCookieHash = this.cookieManager.getSelectedCookieHash();
  }

  async clearImageCache() {
    this.imageCacheManager.clearCache();
    this.cacheSize = "0 MB";
    try {
      this.getUIContext().getPromptAction().showToast({ message: "缓存已清空..." });
    } catch (error) {
      // TODO: Implement error handling.
    }
  }

  async addCookie(hash: string, cookieName: string) {
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
        .onPageEnd(() => {
          this.tryExtractCookieFromWeb();
        })
    }
    .width("100%")
    .height("100%")
    .backgroundColor($r("app.color.background"));
  }

  tryExtractCookieFromWeb() {
    this.webController.runJavaScript("document.cookie", (result: string) => {
      console.info(`[SettingsPage] Web cookies: ${result}`);
      if (result.includes("userhash=")) {
        const hashMatch: RegExpMatchArray | null = result.match(/userhash=([^;]+)/);
        if (hashMatch && hashMatch.length > 1) {
          const cookieHash: string = hashMatch[1];
          console.info(`[SettingsPage] Extracted userhash: ${cookieHash}`);
          if (cookieHash.length > 0) {
            this.addCookie(cookieHash, "网页登录");
            this.showWebSheet = false;
          }
        }
      }
    }).catch(() => {
      // TODO: Implement error handling.
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
              Text("1.0.0")
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
