const fs = require('fs');

const problems = [
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\main.dart","message":"Unused import: 'package:device_preview/device_preview.dart'.\nTry removing the import directive.","severity":"warning","startLine":1,"endLine":1},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_models.dart","message":"Unused import: 'package:flutter/material.dart'.\nTry removing the import directive.","severity":"warning","startLine":2,"endLine":2},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\roulette\\roulette_setup_sheet.dart","message":"Unused import: 'package:get/get.dart'.\nTry removing the import directive.","severity":"warning","startLine":2,"endLine":2},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\waiting_list_bottom_sheet.dart","message":"Unused import: 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_state.dart'.\nTry removing the import directive.","severity":"warning","startLine":8,"endLine":8},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\messages\\components\\bubbles\\document_message.dart","message":"Unused import: 'package:chat_messenger/screens/messages/controllers/message_controller.dart'.\nTry removing the import directive.","severity":"warning","startLine":4,"endLine":4},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\messages\\components\\bubbles\\document_message.dart","message":"Unused import: 'package:get/get.dart'.\nTry removing the import directive.","severity":"warning","startLine":5,"endLine":5},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\explore_tab.dart","message":"Unused import: 'package:chat_messenger/screens/room/video_live_screen.dart'.\nTry removing the import directive.","severity":"warning","startLine":3,"endLine":3},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\explore_tab.dart","message":"Unused import: 'dart:math'.\nTry removing the import directive.","severity":"warning","startLine":11,"endLine":11},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\settings\\update_phone_screen.dart","message":"Unused import: 'package:chat_messenger/components/app_loading.dart'.\nTry removing the import directive.","severity":"warning","startLine":1,"endLine":1},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\AdminPane\\screens\\admin_audio_rooms_screen.dart","message":"'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":313,"endLine":313},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\AdminPane\\screens\\admin_audio_rooms_screen.dart","message":"'activeColor' is deprecated and shouldn't be used. Use activeThumbColor instead. This feature was deprecated after v3.31.0-2.0.pre.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":347,"endLine":347},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\features\\fruit_wheel\\presentation\\bloc\\fruit_wheel_bloc.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":87,"endLine":87},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\features\\fruit_wheel\\presentation\\bloc\\fruit_wheel_bloc.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":187,"endLine":187},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\features\\fruit_wheel\\presentation\\bloc\\fruit_wheel_bloc.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":192,"endLine":192},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\features\\fruit_wheel\\presentation\\bloc\\fruit_wheel_bloc.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":194,"endLine":194},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\live_ended_summary_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":136,"endLine":136},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo_game_widget.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":84,"endLine":84},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_board_widget.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":54,"endLine":54},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_board_widget.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":203,"endLine":203},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_dice_widget.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":118,"endLine":118},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_lobby_widget.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":81,"endLine":81},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_lobby_widget.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":135,"endLine":135},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_lobby_widget.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":187,"endLine":187},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_lobby_widget.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":195,"endLine":195},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_setup_bottom_sheet.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":115,"endLine":115},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_setup_bottom_sheet.dart","message":"'activeColor' is deprecated and shouldn't be used. Use activeThumbColor instead. This feature was deprecated after v3.31.0-2.0.pre.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":136,"endLine":136},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_setup_bottom_sheet.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":192,"endLine":192},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\room_controls.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":851,"endLine":851},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\room_controls.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":853,"endLine":853},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\room_vs_room_pk_overlay.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":192,"endLine":192},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\room_vs_room_pk_overlay.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":275,"endLine":275},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\room_vs_room_pk_overlay.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":346,"endLine":346},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\room_vs_room_pk_overlay.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":347,"endLine":347},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\voting\\voting_result_sheet.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":99,"endLine":99},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\voting\\voting_widget.dart","message":"'activeColor' is deprecated and shouldn't be used. Use activeThumbColor instead. This feature was deprecated after v3.31.0-2.0.pre.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":419,"endLine":419},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\calling\\controller\\call_controller.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":80,"endLine":80},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\calling\\controller\\call_controller.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":83,"endLine":83},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\calling\\incoming_call_screen.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":248,"endLine":248},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\calling\\incoming_call_screen.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":253,"endLine":253},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\calling\\incoming_call_screen.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":281,"endLine":281},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\calling\\incoming_call_screen.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":286,"endLine":286},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\calling\\incoming_call_screen.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":312,"endLine":312},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\calling\\incoming_call_screen.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":317,"endLine":317},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\calling\\incoming_call_screen.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":500,"endLine":500},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\calling\\incoming_call_screen.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":505,"endLine":505},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\calling\\incoming_call_screen.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":510,"endLine":510},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\calling\\incoming_call_screen.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":514,"endLine":514},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\calling\\incoming_call_screen.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":517,"endLine":517},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\calling\\incoming_call_screen.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":523,"endLine":523},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\messages\\components\\appbar_tools.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":57,"endLine":57},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\messages\\components\\appbar_tools.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":58,"endLine":58},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\messages\\components\\appbar_tools.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":59,"endLine":59},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\messages\\components\\appbar_tools.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":60,"endLine":60},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\messages\\components\\appbar_tools.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":61,"endLine":61},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\messages\\controllers\\audio_player_controller.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":32,"endLine":32},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\messages\\controllers\\audio_player_controller.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":62,"endLine":62},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\messages\\controllers\\audio_player_controller.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":72,"endLine":72},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\messages\\controllers\\audio_player_controller.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":88,"endLine":88},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\check.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":111,"endLine":111},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\check.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":386,"endLine":386},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\check.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":441,"endLine":441},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\check.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":443,"endLine":443},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\check.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":447,"endLine":447},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\check.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":450,"endLine":450},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\check.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":453,"endLine":453},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\check.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":456,"endLine":456},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\check.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":517,"endLine":517},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\check.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":520,"endLine":520},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\check.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":561,"endLine":561},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\check.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":564,"endLine":564},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\check.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":654,"endLine":654},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\check.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":1258,"endLine":1258},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\controller\\emoji_controller.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":37,"endLine":37},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\controller\\gift_controller.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":37,"endLine":37},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\controller\\room_controller.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":108,"endLine":108},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\controller\\voice_room_controller.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":61,"endLine":61},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\controller\\voice_room_controller.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":67,"endLine":67},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\controller\\voice_room_controller.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":71,"endLine":71},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\controller\\voice_room_controller.dart","message":"Don't invoke 'print' in production code.\nTry using a logging framework.","severity":"info","startLine":72,"endLine":72},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\earnings_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":309,"endLine":309},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\earnings_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":318,"endLine":318},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\earnings_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":342,"endLine":342},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\earnings_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":512,"endLine":512},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\earnings_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":654,"endLine":654},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\emoji_bottom_sheet.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":59,"endLine":59},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\level_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":87,"endLine":87},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\level_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":96,"endLine":96},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\level_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":122,"endLine":122},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\level_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":215,"endLine":215},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\level_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":220,"endLine":220},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\level_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":310,"endLine":310},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\level_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":400,"endLine":400},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\level_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":487,"endLine":487},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\role_dashboard_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":240,"endLine":240},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\room\\role_dashboard_screen.dart","message":"'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.","severity":"info","startLine":242,"endLine":242}
];

// Group problems by path
const grouped = {};
problems.forEach(p => {
  if (!grouped[p.path]) grouped[p.path] = [];
  grouped[p.path].push(p);
});

for (const path of Object.keys(grouped)) {
  if (!fs.existsSync(path)) continue;
  let content = fs.readFileSync(path, 'utf8');
  let lines = content.split('\n');
  let modified = false;

  const fileProblems = grouped[path];
  // Sort problems in reverse order by startLine to avoid line shifting when deleting
  fileProblems.sort((a, b) => b.startLine - a.startLine);

  for (const p of fileProblems) {
    const lineIndex = p.startLine - 1;
    if (lineIndex < 0 || lineIndex >= lines.length) continue;
    let line = lines[lineIndex];

    if (p.message.includes('Unused import:')) {
      lines.splice(lineIndex, 1);
      modified = true;
    } else if (p.message.includes("Don't invoke 'print'")) {
      if (line.includes('print(')) {
        lines[lineIndex] = line.replace(/print\(/g, 'debugPrint(');
        modified = true;
        // ensure foundation is imported
        if (!lines.some(l => l.includes('package:flutter/foundation.dart'))) {
          lines.splice(0, 0, "import 'package:flutter/foundation.dart';");
        }
      }
    } else if (p.message.includes("'withOpacity' is deprecated")) {
      if (line.includes('.withOpacity(')) {
        lines[lineIndex] = line.replace(/\.withOpacity\(/g, '.withValues(alpha: ');
        modified = true;
      }
    } else if (p.message.includes("'value' is deprecated")) {
      if (line.includes('value:')) {
        lines[lineIndex] = line.replace(/value:/g, 'initialValue:');
        modified = true;
      }
    } else if (p.message.includes("'activeColor' is deprecated")) {
      if (line.includes('activeColor:')) {
        lines[lineIndex] = line.replace(/activeColor:/g, 'activeThumbColor:');
        modified = true;
      }
    }
  }

  if (modified) {
    fs.writeFileSync(path, lines.join('\n'), 'utf8');
    console.log(`Fixed ${path}`);
  }
}
