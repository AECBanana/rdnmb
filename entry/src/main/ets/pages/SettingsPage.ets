import router from "@ohos.router";
import { common } from "@kit.AbilityKit";
import { ImageCacheManager } from "../utils/ImageCacheManager";
import { CookieManager } from "../utils/CookieManager";
import { Cookie, CookieRaw } from "../models/Cookie";
import { promptAction } from "@kit.ArkUI";
import { scanBarcode, scanCore } from "@kit.ScanKit";
import { BusinessError } from "@kit.BasicServicesKit";

@CustomDialog
struct EditCookieDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: () => {}, customStyle: true });
  cookieRaw: CookieRaw = {
    cookieHash: "",
    cookieName: "",
    cookieDisplayName: "",
    lastUsedAt: 0,
    domain: "",
  };
  onConfirm?: (displayName: string) => void;
  @State displayName: string = "";

  aboutToAppear() {
    this.displayName = this.cookieRaw.cookieDisplayName;
  }

  build() {
    Column() {
      Text("编辑饼干名称")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 20 })
      TextInput({ text: this.displayName, placeholder: "显示名称" })
        .width("100%")
        .height(40)
        .margin({ bottom: 20 })
        .onChange((value: string) => {
          this.displayName = value;
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
        Button("保存")
          .width(100)
          .onClick(() => {
            if (this.onConfirm) {
              this.onConfirm(this.displayName);
            }
            this.controller.close();
          })
      }.width("100%")
    }
    .width("100%")
    .padding(20);
  }
}

@CustomDialog
struct ManualAddCookieDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: () => {}, customStyle: true });
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
              promptAction.showToast({ message: "请输入内容" });
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
              promptAction.showToast({ message: "未识别到有效的饼干信息" });
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

  private imageCacheManager: ImageCacheManager = ImageCacheManager.getInstance();
  private cookieManager: CookieManager = CookieManager.getInstance();
  private editDialogController: CustomDialogController | null = null;
  private manualAddDialogController: CustomDialogController | null = null;

  aboutToAppear() {
    this.calculateCacheSize();
    this.loadCookies();
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
    promptAction.showToast({ message: "缓存已清除" });
  }

  async addCookie(hash: string, cookieName: string) {
    const finalDisplayName: string = cookieName.length > 0 ? cookieName : "匿名";
    await this.cookieManager.addCookie(
      hash,
      cookieName.length > 0 ? cookieName : "user",
      finalDisplayName,
    );
    this.loadCookies();
    promptAction.showToast({ message: "饼干添加成功" });
  }

  async deleteCookie(cookieHash: string) {
    await this.cookieManager.deleteCookie(cookieHash);
    this.loadCookies();
    promptAction.showToast({ message: "饼干已删除" });
  }

  async selectCookie(cookieHash: string) {
    await this.cookieManager.setSelectedCookie(cookieHash);
    this.selectedCookieHash = cookieHash;
    promptAction.showToast({ message: "已切换饼干" });
  }

  showEditDialog(cookie: Cookie) {
    this.editDialogController = new CustomDialogController({
      builder: EditCookieDialog({
        cookieRaw: cookie.raw,
        onConfirm: (displayName: string) => {
          this.updateCookieDisplayName(cookie.cookieHash, displayName);
        },
      }),
      customStyle: true,
      alignment: DialogAlignment.Bottom,
      backgroundColor: $r("app.color.card_background"),
    });
    this.editDialogController.open();
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

  async updateCookieDisplayName(cookieHash: string, displayName: string) {
    const finalDisplayName: string = displayName.length > 0 ? displayName : "匿名";
    await this.cookieManager.updateCookieDisplayName(cookieHash, finalDisplayName);
    this.loadCookies();
    promptAction.showToast({ message: "饼干名称已更新" });
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
          promptAction.showToast({ message: "扫码取消或失败" });
        });
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`Start scan failed: ${err.message}`);
      promptAction.showToast({ message: "启动扫码失败" });
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
      promptAction.showToast({ message: "未识别到有效的饼干信息" });
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
    Text("缓存管理")
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor($r("app.color.text_secondary"))
      .width("100%")
      .padding({ left: 16, top: 8, bottom: 8 });
  }

  @Builder
  cookieHeader() {
    Row() {
      Text("饼干管理")
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor($r("app.color.text_secondary"))
      Blank()
      Button("扫码")
        .fontSize(12)
        .fontColor($r("app.color.primary"))
        .backgroundColor("transparent")
        .padding({ left: 4, right: 4 })
        .onClick(() => {
          this.scanQRCodeAndAdd();
        })
      Button("手动")
        .fontSize(12)
        .fontColor($r("app.color.primary"))
        .backgroundColor("transparent")
        .padding({ left: 4, right: 4 })
        .onClick(() => {
          this.showManualAddDialog();
        })
    }
    .width("100%")
    .padding({ left: 16, right: 16, top: 8, bottom: 8 });
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
          Text("← 返回")
            .fontSize(16)
            .fontColor($r("app.color.primary"))
        }
        .backgroundColor("transparent")
        .onClick(() => {
          router.back();
        })
        Text("设置")
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r("app.color.text_primary"))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text("    ")
          .fontSize(16)
          .visibility(Visibility.Hidden)
      }
      .width("100%")
      .padding({ left: 8, right: 8, top: 44, bottom: 8 })
      List() {
        ListItemGroup({ header: this.cacheHeader }) {
          ListItem() {
            Row() {
              Column() {
                Text("图片缓存")
                  .fontSize(16)
                  .fontColor($r("app.color.text_primary"))
                Text(this.cacheSize)
                  .fontSize(12)
                  .fontColor($r("app.color.text_secondary"))
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Button("清除")
                .fontSize(14)
                .fontColor($r("app.color.primary"))
                .backgroundColor("transparent")
                .onClick(() => {
                  this.clearImageCache();
                })
            }
            .width("100%")
            .padding(16)
          }
        }
        ListItemGroup({ header: this.cookieHeader }) {
          if (this.cookies.length === 0) {
            ListItem() {
              Row() {
                Text("暂无饼干，点击上方按钮添加")
                  .fontSize(14)
                  .fontColor($r("app.color.text_secondary"))
              }
              .width("100%")
              .padding(16)
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
                .padding(16)
              };
            });
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
      .layoutWeight(1)
      .backgroundColor($r("app.color.background"))
      .divider({ strokeWidth: 1, color: $r("app.color.divider") })
    }
    .width("100%")
    .height("100%")
    .backgroundColor($r("app.color.background"))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
