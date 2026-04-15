// #include "..\script_component.hpp"
// // Originally from HAC_fnc.sqf (RYD_WPadd)

// /**
//  * @description Adds a configured waypoint to a group with optional pathfinding routing.
//  *              Intermediate waypoints are inserted when pathfinding is enabled and the
//  *              destination exceeds the pathfinding threshold distance.
//  * @param {Group|Array} _groups Group to add waypoint to, or [group] array (array disables full pathfinding)
//  * @param {Array} _pos Target position
//  * @param {String} _type Waypoint type (MOVE, CYCLE, HOOK, ...)
//  * @param {String} _behaviour Group behaviour (AWARE, SAFE, COMBAT, ...)
//  * @param {String} _combatMode Combat mode (YELLOW, RED, GREEN, ...)
//  * @param {String} _speed Movement speed (NORMAL, LIMITED, FULL, ...)
//  * @param {Array} _statements Waypoint statements [condition, onActivation]
//  * @param {Boolean} _setAsCurrent Whether to set the new waypoint as current
//  * @param {Number} _completionRadius Completion radius (0.01 = garrison attach mode — skips flat-land adjustment)
//  * @param {Array} _timeout Waypoint timeout [min, mid, max]
//  * @param {String} _formation Group formation override (empty string = keep current formation)
//  * @return {Waypoint} The created waypoint
//  */
// params [
//     ["_groups", grpNull, [grpNull]],
//     ["_pos", [0, 0, 0]],
//     ["_type", "MOVE", [""]],
//     ["_behaviour", "AWARE", [""]],
//     ["_combatMode", "YELLOW", [""]],
//     ["_speed", "NORMAL", [""]],
//     ["_statements", ["true", "deletewaypoint [(group this), 0]"], [[]]],
//     ["_setAsCurrent", true, [false]],
//     ["_completionRadius", 0, [0]],
//     ["_timeout", [0, 0, 0], [[]]],
//     ["_formation", "", [""]]
// ];

// // If groups passed as array, extract group and disable full pathfinding
// private _pfAll = true;
// if (typeName _groups == "ARRAY") then {
//     _pfAll = false;
//     _groups = _groups select 0;
// };

// // Default formation to the group's current formation when none provided
// if (_formation isEqualTo "") then {
//     _formation = formation _groups;
// };

// // Find the HQ that commands this group via its friends list
// private _HQ = grpNull;
// {
//     private _leader = missionNamespace getVariable [_x, objNull];
//     if !(isNull _leader) then {
//         private _hqGroup = group _leader;
//         if (_groups in (_hqGroup getVariable [QEGVAR(core,friends), []])) then {
//             _HQ = _hqGroup;
//         };
//     };
// } forEach ["leaderHQ", "leaderHQB", "leaderHQC", "leaderHQD", "leaderHQE", "leaderHQF", "leaderHQG", "leaderHQH"];

// // Rush mode: upgrade LIMITED speed and SAFE behaviour
// if (_HQ getVariable [QEGVAR(core,rush), false]) then {
//     if (_speed == "LIMITED") then { _speed = "NORMAL" };
//     if (_behaviour == "SAFE") then { _behaviour = "AWARE" };
// };

// private _addedPath = false;

// // Player-led groups skip pathfinding
// if (isPlayer (leader _groups)) then { _pfAll = false };

// // Clear existing waypoints unless this is a garrison attach (radius 0.01)
// if !(_completionRadius == 0.01) then {
//     [_groups] call CBA_fnc_clearWaypoints;
// };

// // Flat-land adjustment: integer radius triggers flat-land search; decimal (e.g. 0.01) skips it
// private _intRadius = floor _completionRadius;
// if (_intRadius == _completionRadius) then {
//     _pos = [_pos, 50] call FUNC(flatLandNoRoad);
// } else {
//     _completionRadius = 0;
// };

// // For ground vehicles: find a flat empty area near the destination
// private _leaderVeh = assignedVehicle (leader _groups);
// if (
//     !(isNull _leaderVeh) &&
//     {_groups == (group _leaderVeh)} &&
//     {!(_leaderVeh isKindOf "Air")}
// ) then {
//     private _searchRadius = 50;
//     private _posX = _pos select 0;
//     private _posY = _pos select 1;

//     while {_searchRadius <= 400} do {
//         private _flatPos = _pos isFlatEmpty [10, _searchRadius, 1.5, 10, 0, false, objNull];
//         if (count _flatPos > 1) exitWith {
//             _posX = _flatPos select 0;
//             _posY = _flatPos select 1;
//         };
//         _searchRadius = _searchRadius + 50;
//     };

//     if (_posX > 0) then { _pos = [_posX, _posY, 0] };
// };

// // Pathfinding: insert intermediate waypoints when destination is far.
// // Only applies to infantry on foot — mounted groups skip entirely.
// if ((EGVAR(core,pathFinding) > 0) && _pfAll) then {
//     // Find what vehicle the leader (or any unit) is assigned to / riding
//     private _assVeh = assignedVehicle (leader _groups);
//     if (isNull _assVeh) then {
//         {
//             private _vh = assignedVehicle _x;
//             if !(isNull _vh) exitWith { _assVeh = _vh };
//             _vh = vehicle _x;
//             if !(_vh == _x) exitWith { _assVeh = _vh };
//         } forEach (units _groups);
//     };

//     // Mounted groups skip pathfinding — the engine handles vehicle routing
//     if !(isNull _assVeh) exitWith {};

//     // Infantry on foot: subdivide route into terrain-scored intermediate waypoints
//     private _startPoint = getPosATL (vehicle (leader _groups));
//     private _existingWPs = waypoints _groups;
//     if !(count _existingWPs == 0) then {
//         _startPoint = waypointPosition (_existingWPs select ((count _existingWPs) - 1));
//     };

//     private _dst = _startPoint distance _pos;

//     if (_dst > EGVAR(core,pathFinding)) then {
//         private _dstFirst = _dst;

//         while {_dst > EGVAR(core,pathFinding)} do {
//             _dst = floor (_dst / 2);
//         };
//         _dst = _dst * 2;

//         private _numSegments = floor (_dstFirst / _dst);

//         if (_numSegments >= 2) then {
//             private _angle = [_startPoint, _pos, 0] call FUNC(angleTowards);
//             private _midPoints = [];
//             private _actDst = 0;

//             for "_i" from 1 to _numSegments do {
//                 _actDst = _actDst + _dst;
//                 _midPoints pushBack ([_startPoint, _angle, _actDst] call FUNC(positionTowards2D));
//             };

//             // Score each midpoint's neighbourhood and pick the best candidate position
//             private _topPoints = [];
//             {
//                 private _mX = _x select 0;
//                 private _mY = _x select 1;
//                 private _bestScore = -1000000;
//                 private _bestPos = _x;

//                 for "_i" from 1 to 10 do {
//                     private _pfRange = EGVAR(core,pathFinding) * 1.5;
//                     private _samplePos = [
//                         _mX + ((random (_pfRange * 2)) - _pfRange),
//                         _mY + ((random (_pfRange * 2)) - _pfRange)
//                     ];

//                     private _terrain = [_samplePos, 1] call FUNC(terraCognita);
//                     private _urban  = round ((_terrain select 0) * 100);
//                     private _forest = round ((_terrain select 1) * 100);
//                     private _hills  = round ((_terrain select 2) * 100);
//                     private _flat   = round ((_terrain select 3) * 100);
//                     private _roads  = count (_samplePos nearRoads 100);
//                     private _gr     = round  (_terrain select 5);

//                     // Infantry prefers cover; land vehicles prefer open/road terrain
//                     private _score = _urban + _forest + _gr - _flat - _hills;

//                     if (_score > _bestScore) then {
//                         _bestPos = _samplePos;
//                         _bestScore = _score;
//                     };
//                 };

//                 private _bX = _bestPos select 0;
//                 private _bY = _bestPos select 1;
//                 if !(surfaceIsWater [_bX, _bY]) then {
//                     _topPoints pushBack [_bX, _bY, 0];
//                 };
//             } forEach _midPoints;

//             if (count _topPoints > 0) then {
//                 private _wpIdx = 0;
//                 private _rushTimeout = [0, 0, 0];
//                 if (_HQ getVariable [QEGVAR(core,rush), false] && {_speed in ["NORMAL"]}) then {
//                     _rushTimeout = [15, 20, 25];
//                 };

//                 {
//                     if (EGVAR(common,debug)) then {
//                         [_x, _groups, (str (random 1000)), "ColorPink", "ICON", "mil_dot", (str _wpIdx), "", [0.25, 0.25]] call FUNC(mark);
//                     };
//                     _wpIdx = _wpIdx + 1;
//                     private _midWP = _groups addWaypoint [_x, 0];
//                     _midWP setWaypointType "MOVE";
//                     if (_foreachIndex == 0) then {
//                         _midWP setWaypointBehaviour _behaviour;
//                         _midWP setWaypointCombatMode _combatMode;
//                         _midWP setWaypointSpeed _speed;
//                         _midWP setWaypointFormation _formation;
//                     };
//                     _midWP setWaypointStatements ["true", "deletewaypoint [(group this), 0]"];
//                     _midWP setWaypointTimeout _rushTimeout;
//                     if (_setAsCurrent && {_wpIdx == 1}) then { _groups setCurrentWaypoint _midWP };
//                 } forEach _topPoints;

//                 _addedPath = true;
//             };
//         };
//     };
// };

// // Add the final destination waypoint
// private _wp = _groups addWaypoint [_pos, _completionRadius];
// _wp setWaypointType _type;

// // HOOK waypoint: attach ammo box if one is assigned to the group
// if (_type == "HOOK" && {!(isNull (_groups getVariable ["AmmBox" + (str _groups), objNull]))}) then {
//     _wp waypointAttachVehicle (_groups getVariable ["AmmBox" + (str _groups), objNull]);
//     _groups setVariable ["AmmBox" + (str _groups), objNull];
// };

// _wp setWaypointStatements _statements;
// _wp setWaypointTimeout _timeout;

// // Only set behaviour/speed on final WP when no intermediate path was inserted
// if !(_addedPath) then {
//     _wp setWaypointBehaviour _behaviour;
//     _wp setWaypointCombatMode _combatMode;
//     _wp setWaypointSpeed _speed;
//     _wp setWaypointFormation _formation;
//     if (_setAsCurrent) then { _groups setCurrentWaypoint _wp };
// };

// _wp

#include "..\script_component.hpp"
// Originally from nr6_hal/HAC_fnc.sqf (RYD_WPadd)

/**
 * @description Adds a configured waypoint to a group.
 * @param {Group} Group to add waypoint to
 * @param {Array} Position [x, y, z]
 * @param {String} Waypoint type (MOVE, HOLD, CYCLE, SAD, ...)
 * @param {String} Behaviour (AWARE, COMBAT, SAFE, ...)
 * @param {String} Combat mode (RED, YELLOW, GREEN, BLUE, WHITE)
 * @param {String} Speed (FULL, NORMAL, LIMITED)
 * @param {Array} Statements [condition, onActivation]
 * @param {Boolean} Show waypoint on map
 * @param {Number} Completion radius in metres
 * @param {Array} [Optional] Timeout [min, mid, max]
 * @param {String} [Optional] Formation (NO CHANGE, FILE, DIAMOND, ...)
 * @return {Array} Created waypoint [group, waypointIndex]
 */
// Accept either a group directly or a legacy [group] array-wrapped call site.
private _rawGroup = _this param [0, grpNull];
private _group = if (_rawGroup isEqualType []) then { _rawGroup param [0, grpNull] } else { _rawGroup };

params [
    "",
    ["_pos", [0, 0, 0]],
    ["_type", "MOVE", [""]],
    ["_behaviour", "AWARE", [""]],
    ["_combatMode", "YELLOW", [""]],
    ["_speed", "NORMAL", [""]],
    ["_statements", ["true", ""], [[]]],
    ["_show", false, [false]],
    ["_completionRadius", 0, [0]],
    ["_timeout", [0, 0, 0], [[]]],
    ["_formation", "NO CHANGE", [""]]
];

if (isNull _group) exitWith { [] };

private _wp = _group addWaypoint [_pos, 0];

_wp setWaypointType _type;
_wp setWaypointBehaviour _behaviour;
_wp setWaypointCombatMode _combatMode;
_wp setWaypointSpeed _speed;
_wp setWaypointStatements _statements;
_wp setWaypointVisible _show;
_wp setWaypointCompletionRadius _completionRadius;
_wp setWaypointTimeout _timeout;
_wp setWaypointFormation _formation;

_wp
