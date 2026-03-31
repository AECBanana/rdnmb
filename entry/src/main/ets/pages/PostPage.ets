import router from '@ohos.router';
import { AnoBBSClient } from '../api/Client';
import { ApiException, NetworkException, RequiresLoginException } from '../models/Errors';

interface RouterParams {
  fid?: string;
  boardName?: string;
  resto?: string;
  threadId?: string;
}

@Entry
@Component
struct PostPage {
  private client: AnoBBSClient = new AnoBBSClient();
  @State private fid: string = '';
  @State private boardName: string = '';
  @State private resto: string = '';
  @State private threadId: string = '';
  @State private content: string = '';
  @State private name: string = '';
  @State private email: string = '';
  @State private title: string = '';
  @State private water: string = '';
  @State private isPosting: boolean = false;
  @State private errorMessage: string = '';
  @State private successMessage: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as RouterParams;
    if (params) {
      if (params.fid) {
        this.fid = params.fid;
      }
      if (params.boardName) {
        this.boardName = params.boardName;
      }
      if (params.resto) {
        this.resto = params.resto;
      }
      if (params.threadId) {
        this.threadId = params.threadId;
      }
    }
  }

  async doPost(): Promise<void> {
    if (this.content.trim().length === 0) {
      this.errorMessage = '内容不能为空';
      return;
    }

    this.isPosting = true;
    this.errorMessage = '';
    this.successMessage = '';

    try {
      let result: string;
      if (this.resto.length > 0) {
        result = await this.client.postReply(
          this.resto,
          this.content,
          this.name.length > 0 ? this.name : undefined,
          this.email.length > 0 ? this.email : undefined,
          this.title.length > 0 ? this.title : undefined,
          this.water.length > 0 ? this.water : undefined
        );
        this.successMessage = `回复成功！ID: ${result}`;
      } else {
        result = await this.client.postNewThread(
          this.fid,
          this.content,
          this.name.length > 0 ? this.name : undefined,
          this.email.length > 0 ? this.email : undefined,
          this.title.length > 0 ? this.title : undefined,
          this.water.length > 0 ? this.water : undefined
        );
        this.successMessage = `发串成功！ID: ${result}`;
      }

      setTimeout(() => {
        router.back();
      }, 1500);
    } catch (error) {
      if (error instanceof RequiresLoginException) {
        this.errorMessage = '需要登录才能发串';
      } else if (error instanceof ApiException) {
        this.errorMessage = `发串失败: ${error.message}`;
      } else if (error instanceof NetworkException) {
        this.errorMessage = `网络错误: ${error.message}`;
      } else {
        const err = error as Error;
        this.errorMessage = `发串失败: ${err.message}`;
      }
    } finally {
      this.isPosting = false;
    }
  }

  build() {
    Column() {
      Row() {
        Button() {
          Text('返回')
            .fontSize(16)
            .fontColor($r('app.color.primary'))
        }
        .backgroundColor('transparent')
        .onClick(() => {
          router.back();
        })

        Text(this.resto.length > 0 ? `回复 No.${this.threadId}` : `发新串 - ${this.boardName}`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button() {
          Text('发送')
            .fontSize(16)
            .fontColor(Color.White)
        }
        .backgroundColor($r('app.color.primary'))
        .enabled(!this.isPosting)
        .onClick(() => {
          this.doPost();
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 44, bottom: 12 })
      .backgroundColor($r('app.color.card_background'))

      if (this.errorMessage.length > 0) {
        Row() {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor($r('app.color.error'))
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#33FF0000')
        .borderRadius(8)
        .margin({ left: 16, right: 16, top: 12 })
      }

      if (this.successMessage.length > 0) {
        Row() {
          Text(this.successMessage)
            .fontSize(14)
            .fontColor($r('app.color.success'))
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#334CAF50')
        .borderRadius(8)
        .margin({ left: 16, right: 16, top: 12 })
      }

      Scroll() {
        Column() {
          if (this.resto.length === 0) {
            Column() {
              Text('标题 (可选)')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .margin({ bottom: 4 })
              TextInput({ text: this.title, placeholder: '输入标题...' })
                .width('100%')
                .onChange((value: string) => {
                  this.title = value;
                })
            }
            .width('100%')
            .margin({ bottom: 16 })
          }

          Column() {
            Text('内容')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .margin({ bottom: 4 })
            TextArea({ text: this.content, placeholder: '输入内容...' })
              .width('100%')
              .height(200)
              .onChange((value: string) => {
                this.content = value;
              })
          }
          .width('100%')
          .margin({ bottom: 16 })

          Column() {
            Text('昵称 (可选)')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .margin({ bottom: 4 })
            TextInput({ text: this.name, placeholder: '输入昵称...' })
              .width('100%')
              .onChange((value: string) => {
                this.name = value;
              })
          }
          .width('100%')
          .margin({ bottom: 16 })

          Column() {
            Text('邮箱 (可选)')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .margin({ bottom: 4 })
            TextInput({ text: this.email, placeholder: '输入邮箱...' })
              .width('100%')
              .onChange((value: string) => {
                this.email = value;
              })
          }
          .width('100%')
          .margin({ bottom: 16 })

          Column() {
            Text('水印 (可选)')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .margin({ bottom: 4 })
            TextInput({ text: this.water, placeholder: '输入水印...' })
              .width('100%')
              .onChange((value: string) => {
                this.water = value;
              })
          }
          .width('100%')
          .margin({ bottom: 16 })
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .backgroundColor($r('app.color.background'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
