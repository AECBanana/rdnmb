import { Community, Timeline, Forum } from "../models/Forum";

@Component
export struct BoardDrawer {
  @Prop currentBoardId: number = -1;
  @Prop communities: Community[] = [];
  @Prop timelines: Timeline[] = [];
  @Prop boardsLoading: boolean = false;
  @Link isShow: boolean;
  onBoardSelect?: (boardId: number, boardName: string, isTimeline: boolean) => void;

  build() {
    Column() {
      Row() {
        Column() {
          Row() {
            Text("版块列表")
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r("app.color.text_primary"))
              .layoutWeight(1)
          }
          .width("100%")
          .padding(16)
          .margin({ top: 44 })

          if (this.boardsLoading && this.communities.length === 0) {
            Column() {
              LoadingProgress()
                .width(32)
                .height(32)
                .color($r("app.color.primary"))
              Text("加载版块列表...")
                .fontSize(12)
                .fontColor($r("app.color.text_secondary"))
                .margin({ top: 8 })
            }
            .width("100%")
            .height(200)
            .justifyContent(FlexAlign.Center);
          } else {
            List() {
              if (this.timelines.length > 0) {
                ListItem() {
                  Text("时间线")
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .padding(8)
                    .fontColor($r("app.color.text_secondary"))
                    .width("100%")
                    .backgroundColor($r("app.color.background"))
                };
              }
              ForEach(this.timelines, (timeline: Timeline) => {
                ListItem() {
                  Column() {
                    Text(timeline.displayName)
                      .fontSize(16)
                      .padding(8)
                      .fontColor(
                        this.currentBoardId === -timeline.id
                          ? $r("app.color.primary")
                          : $r("app.color.text_primary"),
                      )
                      .width("100%")
                      .backgroundColor(
                        this.currentBoardId === -timeline.id
                          ? $r("app.color.reply_count_bg")
                          : "transparent",
                      )
                      .borderRadius(16)
                      .onClick(() => {
                        if (this.onBoardSelect) {
                          this.onBoardSelect(-timeline.id, timeline.displayName, true);
                        }
                        this.isShow = false;
                      })
                  }
                };
              })
              ForEach(this.communities, (community: Community) => {
                ListItem() {
                  Column() {
                    Text(community.name)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r("app.color.text_secondary"))
                      .width("100%")
                      .padding(8)
                      .backgroundColor($r("app.color.background"))
                    ForEach(community.forums, (forum: Forum) => {
                      if (forum.isValid()) {
                        Text(forum.displayName)
                          .fontSize(16)
                          .fontColor(
                            this.currentBoardId === forum.id
                              ? $r("app.color.primary")
                              : $r("app.color.text_primary"),
                          )
                          .width("100%")
                          .padding(8)
                          .backgroundColor(
                            this.currentBoardId === forum.id
                              ? $r("app.color.reply_count_bg")
                              : "transparent",
                          )
                          .borderRadius(16)
                          .onClick(() => {
                            if (this.onBoardSelect) {
                              this.onBoardSelect(forum.id, forum.displayName, false);
                            }
                            this.isShow = false;
                          });
                      }
                    })
                  }.width("100%")
                };
              })
            }
            .width("100%")
            .height("100%")
            .layoutWeight(1)
            .chainAnimation(true)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .divider({ strokeWidth: 1, color: $r("app.color.divider") });
          }
        }
        .width(280)
        .height("100%")
        .backgroundColor($r("app.color.card_background"))
        Column()
          .layoutWeight(1)
          .height("100%")
          .backgroundColor("#80000000")
          .onClick(() => {
            this.isShow = false;
          })
      }
      .width("100%")
      .height("100%")
    }
    .width("100%")
    .height("100%");
  }
}
