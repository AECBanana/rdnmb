import { AnoBBSClient } from "../api/Client";
import { ApiException, NetworkException, RequiresLoginException } from "../models/Errors";
import { picker } from "@kit.CoreFileKit";
import { fileIo } from "@kit.CoreFileKit";
import { resourceManager } from "@kit.LocalizationKit";
import { util } from "@kit.ArkTS";
import { SettingsManager } from "../utils/SettingsManager";

interface EmojiCategory {
  name: string;
  emojis: string[];
}
@Component
export struct ReplySheet {
  private client: AnoBBSClient = new AnoBBSClient();
  private settingsManager: SettingsManager = SettingsManager.getInstance();
  @Prop resto: string = "";
  @Prop threadId: string = "";
  @Prop replyToId: string = "";
  @State content: string = "";
  @State isPosting: boolean = false;
  @State errorMessage: string = "";
  @State successMessage: string = "";
  @State selectedImageUri: string = "";
  @State selectedImageName: string = "";
  @State showEmojiPicker: boolean = false;
  @State currentEmojiCategory: number = 0;
  @State emojiCategories: EmojiCategory[] = [];
  @State favoriteEmojis: string[] = [];
  @Link isShow: boolean;
  onReplySuccess?: (replyId: string) => void;

  async aboutToAppear(): Promise<void> {
    await this.settingsManager.waitForInit();
    this.favoriteEmojis = this.settingsManager.getFavoriteEmojis();
    const savedCategory: number = this.settingsManager.getEmojiCategoryIndex();

    await this.loadEmojiData();

    if (this.favoriteEmojis.length === 0 && this.emojiCategories.length > 1) {
      this.currentEmojiCategory = 1;
    } else {
      this.currentEmojiCategory = savedCategory;
    }

    if (this.replyToId.length > 0) {
      this.content = `>>No.${this.replyToId}\n`;
    }
  }

  async loadEmojiData(): Promise<void> {
    try {
      const context = getContext(this);
      const resMgr: resourceManager.ResourceManager = context.resourceManager;
      const jsonData: Uint8Array = await resMgr.getRawFileContent("emoji.json");
      const jsonString: string = new util.TextDecoder("utf-8").decodeToString(jsonData);
      const emojiData: EmojiCategory[] = JSON.parse(jsonString) as EmojiCategory[];
      this.emojiCategories = emojiData;
      console.info(`[ReplySheet] Loaded ${emojiData.length} emoji categories`);
    } catch (error) {
      console.error(`[ReplySheet] Failed to load emoji data: ${error}`);
      this.emojiCategories = [];
    }
  }

  async selectImage(): Promise<void> {
    try {
      const photoPicker = new picker.PhotoViewPicker();
      const result = await photoPicker.select({
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1,
      });

      if (result.photoUris.length > 0) {
        this.selectedImageUri = result.photoUris[0];
        const uriParts: string[] = this.selectedImageUri.split("/");
        this.selectedImageName = uriParts[uriParts.length - 1] || "image.jpg";
        console.info(`[ReplySheet] Selected image: ${this.selectedImageUri}`);
      }
    } catch (error) {
      console.error(`[ReplySheet] Select image error: ${error}`);
      this.errorMessage = "选择图片失败";
    }
  }

  removeImage(): void {
    this.selectedImageUri = "";
    this.selectedImageName = "";
  }

  insertEmoji(emoji: string): void {
    this.content = this.content + emoji;
    this.addToFavorite(emoji);
  }

  async addToFavorite(emoji: string): Promise<void> {
    await this.settingsManager.addFavoriteEmoji(emoji);
    this.favoriteEmojis = this.settingsManager.getFavoriteEmojis();
  }

  async onCategoryChange(index: number): Promise<void> {
    this.currentEmojiCategory = index;
    await this.settingsManager.setEmojiCategoryIndex(index);
  }

  getDisplayCategories(): EmojiCategory[] {
    const categories: EmojiCategory[] = [
      { name: "常用", emojis: this.favoriteEmojis },
      ...this.emojiCategories,
    ];
    return categories;
  }

  async doPost(): Promise<void> {
    if (this.content.trim().length === 0 && this.selectedImageUri.length === 0) {
      this.errorMessage = "内容或图片不能同时为空";
      return;
    }

    this.isPosting = true;
    this.errorMessage = "";

    try {
      let imageFilePath: string = "";
      console.info(`[ReplySheet] selectedImageUri: ${this.selectedImageUri}`);
      console.info(`[ReplySheet] selectedImageName: ${this.selectedImageName}`);
      if (this.selectedImageUri.length > 0) {
        const context = getContext(this);
        const cachePath = context.cacheDir + "/" + this.selectedImageName;
        console.info(`[ReplySheet] Copying image from ${this.selectedImageUri} to ${cachePath}`);
        const srcFile = fileIo.openSync(this.selectedImageUri, fileIo.OpenMode.READ_ONLY);
        const destFile = fileIo.openSync(
          cachePath,
          fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE,
        );
        fileIo.copyFileSync(srcFile.fd, destFile.fd);
        fileIo.closeSync(srcFile);
        fileIo.closeSync(destFile);
        imageFilePath = destFile.path;
        console.info(`[ReplySheet] Image copied to: ${destFile.path}`);
        console.info(`[ReplySheet] imageFilePath: ${imageFilePath}`);
      }

      const result: string = await this.client.postReply(
        this.resto,
        this.content,
        undefined,
        undefined,
        undefined,
        undefined,
        imageFilePath.length > 0 ? imageFilePath : undefined,
      );
      this.content = "";
      this.selectedImageUri = "";
      this.selectedImageName = "";
      if (this.onReplySuccess) {
        this.onReplySuccess(result);
        this.getUIContext().getPromptAction().showToast({ message: "回复成功" });
      }
      setTimeout(() => {
        this.isShow = false;
      }, 1500);
    } catch (error) {
      if (error instanceof RequiresLoginException) {
        this.errorMessage = "需要登录才能回复";
      } else if (error instanceof ApiException) {
        this.errorMessage = `回复失败: ${error.message}`;
      } else if (error instanceof NetworkException) {
        this.errorMessage = `网络错误: ${error.message}`;
      } else {
        const err = error as Error;
        this.errorMessage = `回复失败: ${err.message}`;
      }
    } finally {
      this.isPosting = false;
    }
  }

  @Builder
  emojiGridBuilder() {
    Column() {
      Scroll() {
        Row() {
          ForEach(this.getDisplayCategories(), (category: EmojiCategory, index: number) => {
            Button(category.name)
              .fontSize(12)
              .height(28)
              .padding({ left: 14, right: 14 })
              .backgroundColor(
                this.currentEmojiCategory === index
                  ? $r("app.color.primary")
                  : $r("app.color.reply_count_bg"),
              )
              .fontColor(
                this.currentEmojiCategory === index ? Color.White : $r("app.color.text_secondary"),
              )
              .margin({ right: 4 })
              .onClick(() => {
                this.onCategoryChange(index);
              });
          })
        }
        .padding({ bottom: 8 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width("100%")

      if (
        this.getDisplayCategories().length > 0 &&
        this.getDisplayCategories()[this.currentEmojiCategory]
      ) {
        Scroll() {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(
              this.getDisplayCategories()[this.currentEmojiCategory].emojis,
              (emoji: string) => {
                Button() {
                  Text(emoji)
                    .fontSize(16)
                    .width("auto")
                    .height("auto")
                }
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .fontColor($r("app.color.text_primary"))
                .backgroundColor($r("app.color.emoji_button_background"))
                .margin({ bottom: 8, right: 8 })
                .onClick(() => {
                  this.insertEmoji(emoji);
                });
              },
            )
          }
          .width("100%")
          .height("auto")
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
        .width("100%")
        .height(300);
      }
    }
    .width("100%")
    .padding(8)
    .margin({ top: 24 })
    .backgroundColor($r("app.color.card_background"));
  }

  build() {
    Column() {
      Row() {
        Text(`回复 No.${this.threadId}`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r("app.color.text_primary"))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
      }
      .width("100%")
      .padding({ left: 16, right: 16, top: 24, bottom: 24 })

      if (this.errorMessage.length > 0) {
        Row() {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor($r("app.color.error"))
        }
        .width("100%")
        .padding(12)
        .backgroundColor("#33FF0000")
        .borderRadius(8)
        .margin({ left: 16, right: 16, top: 8 });
      }
      Column() {
        TextArea({ text: this.content, placeholder: "输入内容..." })
          .width("100%")
          .height(120)
          .onChange((value: string) => {
            this.content = value;
          })

        if (this.selectedImageUri.length > 0) {
          Row() {
            Text(this.selectedImageName)
              .fontSize(14)
              .fontColor($r("app.color.text_secondary"))
              .layoutWeight(1)
            Button() {
              SymbolGlyph($r("sys.symbol.xmark")).fontSize(16)
            }
            .backgroundColor(Color.Transparent)
            .width(32)
            .height(32)
            .onClick(() => {
              this.removeImage();
            })
          }
          .width("100%")
          .padding(8)
          .backgroundColor($r("app.color.reply_count_bg"))
          .borderRadius(8)
          .margin({ top: 8, bottom: 8 });
        }
        Row() {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r("sys.symbol.face_smiling"))
              .fontSize(14)
              .fontColor([
                this.showEmojiPicker ? $r("app.color.primary") : $r("app.color.text_secondary"),
              ])
          }
          .backgroundColor(
            this.showEmojiPicker ? $r("app.color.reply_count_bg") : Color.Transparent,
          )
          .height(36)
          .width(36)
          .onClick(() => {
            this.showEmojiPicker = !this.showEmojiPicker;
          })
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r("sys.symbol.picture"))
              .fontSize(14)
              .fontColor([
                this.selectedImageUri.length > 0
                  ? $r("app.color.primary")
                  : $r("app.color.text_secondary"),
              ])
          }
          .backgroundColor(Color.Transparent)
          .height(36)
          .width(36)
          .margin({ left: 16 })
          .onClick(() => {
            this.selectImage();
          })
          Blank()
          Button() {
            Text("发送")
              .fontSize(16)
              .fontColor(Color.White)
          }
          .backgroundColor($r("app.color.primary"))
          .enabled(!this.isPosting)
          .height(36)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.doPost();
          })
        }
        .width("100%")
        .margin({ top: 16 })
        .justifyContent(FlexAlign.Start)

        if (this.showEmojiPicker) {
          this.emojiGridBuilder();
        }
      }
      .width("100%")
      .padding({ left: 16, right: 16, bottom: 32 })
    }
    .width("100%")
    .backgroundColor($r("app.color.card_background"))
    .borderRadius({ topLeft: 16, topRight: 16 });
  }
}
