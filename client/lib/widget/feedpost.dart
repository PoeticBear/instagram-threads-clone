import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:threads/helper/utility.dart';
import 'package:threads/model/post.module.dart';
import 'package:threads/state/post.state.dart';
import 'package:threads/widget/poll_widget.dart';

// ignore: must_be_immutable
class FeedPostWidget extends StatefulWidget {
  PostModel postModel;
  FeedPostWidget({required this.postModel, super.key});

  @override
  State<FeedPostWidget> createState() => _FeedPostWidgetState();
}

class _FeedPostWidgetState extends State<FeedPostWidget> {
  @override
  Widget build(BuildContext context) {
    final user = widget.postModel.user;
    final profilePic = user?.profilePic ?? '';
    final displayName = user?.displayName ?? 'Unknown';
    final hasImage = widget.postModel.imagePath != null &&
        widget.postModel.imagePath!.isNotEmpty;
    final hasPoll = widget.postModel.pollData != null;

    Widget avatar(String url, double size) {
      if (url.isEmpty) {
        return Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person, size: size * 0.6, color: Colors.grey[600]),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: Container(
          height: size,
          width: size,
          child: CachedNetworkImage(imageUrl: url),
        ),
      );
    }

    return Container(
        color: Colors.black,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              height: 0.2,
              width: MediaQuery.of(context).size.width,
              color: Colors.grey,
            ),
            Container(
              height: 10,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                avatar(profilePic, 35),
                Container(
                  width: 5,
                ),
                Text(
                  displayName,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  width: MediaQuery.of(context).size.width / 4,
                ),
                Text(
                  Utility.getdob(widget.postModel.createdAt),
                  style:
                      TextStyle(color: const Color.fromARGB(255, 78, 78, 78)),
                ),
                Container(
                  width: 5,
                ),
                Icon(Icons.more_horiz, color: Colors.white)
              ],
            ),
            Padding(
                padding: EdgeInsets.only(left: 55),
                child: Text(
                  widget.postModel.bio ?? '',
                  style: TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontWeight: FontWeight.w500,
                      fontSize: 18),
                )),
            hasPoll
                ? PollWidget(
                    postId: widget.postModel.id,
                    pollData: widget.postModel.pollData!,
                  )
                : !hasImage
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 12,
                          ),
                          Column(
                            children: [
                              Container(
                                width: 2,
                                height: 30,
                                color: const Color.fromARGB(255, 46, 46, 46),
                              ),
                              Container(
                            height: 5,
                          ),
                              avatar(profilePic, 15),
                            ],
                          ),
                          Padding(
                              padding: EdgeInsets.only(left: 20, right: 10),
                              child: SizedBox.shrink()),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 10,
                          ),
                          Column(
                            children: [
                              Container(
                                width: 2,
                                height: 300,
                                color: const Color.fromARGB(255, 46, 46, 46),
                              ),
                              Container(
                                height: 5,
                              ),
                              avatar(profilePic, 15),
                            ],
                          ),
                          Padding(
                              padding: EdgeInsets.only(left: 48, right: 10),
                              child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: CachedNetworkImage(
                                          height: 300,
                                          width: 290,
                                          fit: BoxFit.cover,
                                          imageUrl: widget.postModel.imagePath!,
                                          placeholder: (context, url) => Container(
                                            height: 300,
                                            width: 290,
                                            color: Colors.grey[900],
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            height: 300,
                                            width: 290,
                                            color: Colors.grey[900],
                                            child: Icon(Icons.broken_image, color: Colors.grey[600]),
                                          ),
                                      ))),
                        ],
                      ),
            Container(
              height: 10,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                ),
                GestureDetector(
                  onTap: () {
                    final state = Provider.of<PostState>(context, listen: false);
                    final postId = widget.postModel.id;
                    if (widget.postModel.isLiked == true) {
                      state.unlikePost(postId);
                    } else {
                      state.likePost(postId);
                    }
                  },
                  child: Icon(
                    widget.postModel.isLiked == true
                        ? Iconsax.heart5
                        : Iconsax.heart,
                    size: 20,
                    color: widget.postModel.isLiked == true
                        ? Colors.red
                        : Colors.white,
                  ),
                ),
                Container(width: 4),
                Text('${widget.postModel.likesCount ?? 0}', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Container(width: 10),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.black,
                      builder: (context) => Container(
                        height: MediaQuery.of(context).size.height * 0.9,
                        child: Center(
                          child: Text('评论', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    );
                  },
                  child: Icon(
                    Iconsax.message,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                Container(width: 4),
                Text('${widget.postModel.repliesCount ?? 0}', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Container(width: 10),
                Icon(
                  Iconsax.repeat,
                  size: 20,
                ),
                Container(width: 4),
                Text('${widget.postModel.repostsCount ?? 0}', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Container(width: 10),
                Icon(
                  Iconsax.send_2,
                  size: 20,
                ),
                Container(width: 4),
                Text('${widget.postModel.repliesCount ?? 0}', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            Container(
              height: 15,
            ),
          ],
        ));
  }
}
