import '../core/game_definition.dart';
import 'block_path/block_path_game.dart';
import 'code_breaker/code_breaker_game.dart';
import 'dungeon_logic/dungeon_logic_game.dart';
import 'defuse_protocol/defuse_protocol_game.dart';
import 'flow_connect/flow_connect_game.dart';
import 'gradient_sort/gradient_sort_game.dart';
import 'impossible_paths/impossible_paths_game.dart';
import 'lights_out/lights_out_game.dart';
import 'line_trace/line_trace_game.dart';
import 'loop_trace/loop_trace_game.dart';
import 'merge2048/merge2048_game.dart';
import 'physics_logic/physics_logic_game.dart';
import 'ragdoll_trials/ragdoll_trials_game.dart';
import 'rule_breaker/rule_breaker_game.dart';
import 'slide_escape/slide_escape_game.dart';
import 'snip_logic/snip_logic_game.dart';
import 'sudoku/sudoku_game.dart';
import 'tactics_grid/tactics_grid_game.dart';
import 'transit_planner/transit_planner_game.dart';
import 'trick_logic/trick_logic_game.dart';

/// Every game shown on the home screen, in display order.
/// Each entry is added here once its module is implemented.
final List<GameDefinition> gameRegistry = [
  sudokuDefinition,
  merge2048Definition,
  ruleBreakerDefinition,
  impossiblePathsDefinition,
  lineTraceDefinition,
  loopTraceDefinition,
  lightsOutDefinition,
  blockPathDefinition,
  gradientSortDefinition,
  dungeonLogicDefinition,
  transitPlannerDefinition,
  defuseProtocolDefinition,
  physicsLogicDefinition,
  trickLogicDefinition,
  flowConnectDefinition,
  slideEscapeDefinition,
  snipLogicDefinition,
  ragdollTrialsDefinition,
  tacticsGridDefinition,
  codeBreakerDefinition,
];
