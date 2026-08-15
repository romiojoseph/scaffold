import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum AppSvgIcon {
  arrowCounterClockwise('assets/icons/arrow-counter-clockwise-duotone.svg'),
  caretDownBold('assets/icons/caret-down-bold.svg'),
  caretRightBold('assets/icons/caret-right-bold.svg'),
  chat('assets/icons/chat-duotone.svg'),
  checkCircleFill('assets/icons/check-circle-fill.svg'),
  code('assets/icons/code-duotone.svg'),
  copy('assets/icons/copy-duotone.svg'),
  download('assets/icons/download-duotone.svg'),
  fileArchive('assets/icons/file-archive-duotone.svg'),
  fileCode('assets/icons/file-code-duotone.svg'),
  fileDashed('assets/icons/file-dashed-duotone.svg'),
  file('assets/icons/file-duotone.svg'),
  folderOpen('assets/icons/folder-open-duotone.svg'),
  folders('assets/icons/folders-duotone.svg'),
  funnel('assets/icons/funnel-duotone.svg'),
  gearSix('assets/icons/gear-six-duotone.svg'),
  hardDrives('assets/icons/hard-drives-duotone.svg'),
  image('assets/icons/image-duotone.svg'),
  lineVertical('assets/icons/line-vertical-duotone.svg'),
  listNumbers('assets/icons/list-numbers-duotone.svg'),
  magnifyingGlass('assets/icons/magnifying-glass-duotone.svg'),
  menuBold('assets/icons/menu-bold.svg'),
  presentationChart('assets/icons/presentation-chart-duotone.svg'),
  scan('assets/icons/scan-duotone.svg'),
  terminal('assets/icons/terminal-duotone.svg'),
  toggleLeft('assets/icons/toggle-left-duotone.svg'),
  toggleRight('assets/icons/toggle-right-fill.svg'),
  treeStructure('assets/icons/tree-structure-duotone.svg'),
  trash('assets/icons/trash-duotone.svg'),
  xBold('assets/icons/x-bold.svg'),
  arrowLeftBold('assets/icons/arrow-left-bold.svg'),
  checkSquareFill('assets/icons/check-square-fill.svg'),
  squareDuotone('assets/icons/square-duotone.svg'),
  checkBold('assets/icons/check-bold.svg'),
  sparkleDuotone('assets/icons/sparkle-duotone.svg'),
  gitCommitDuotone('assets/icons/git-commit-duotone.svg'),
  circlesThreePlusDuotone('assets/icons/circles-three-plus-duotone.svg'),
  linkDuotone('assets/icons/link-duotone.svg'),
  packageDuotone('assets/icons/package-duotone.svg'),
  funnelSimpleBold('assets/icons/funnel-simple-bold.svg'),
  caretUpFill('assets/icons/caret-up-fill.svg'),
  radioactiveFill('assets/icons/radioactive-fill.svg'),
  shieldWarningFill('assets/icons/shield-warning-fill.svg'),
  arrowUpFill('assets/icons/arrow-up-fill.svg'),
  foldersFill('assets/icons/folders-fill.svg'),
  fileCodeFill('assets/icons/file-code-fill.svg'),
  gitCommitFill('assets/icons/git-commit-fill.svg'),
  circlesThreePlusFill('assets/icons/circles-three-plus-fill.svg'),
  trashFill('assets/icons/trash-fill.svg'),
  filesFill('assets/icons/files-fill.svg'),
  hardDrivesFill('assets/icons/hard-drives-fill.svg'),
  sparkleFill('assets/icons/sparkle-fill.svg'),
  passwordFill('assets/icons/password-fill.svg'),
  passwordDuotone('assets/icons/password-duotone.svg'),
  eyeSlashFill('assets/icons/eye-slash-fill.svg'),
  eyeDuotone('assets/icons/eye-duotone.svg'),
  infoDuotone('assets/icons/info-duotone.svg'),
  arrowSquareOutDuotone('assets/icons/arrow-square-out-duotone.svg');

  final String assetPath;
  const AppSvgIcon(this.assetPath);
}

class AppIcon extends StatelessWidget {
  final AppSvgIcon icon;
  final double? size;
  final Color? color;
  final BoxFit fit;

  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext meContext) {
    final double iconSize = size ?? 20.0;
    return SvgPicture.asset(
      icon.assetPath,
      width: iconSize,
      height: iconSize,
      fit: fit,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
