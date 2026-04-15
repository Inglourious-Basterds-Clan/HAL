#include "..\script_component.hpp"
// Originally from nr6_hal/Front.sqf -- front-line detection

private _code = {
	params ["_HQ","_front","_ia"];

	while {!(isNull _HQ)} do {
		sleep 5;

		_ia setMarkerPosLocal (position _front);
		_ia setMarkerDirLocal (direction _front);
		_ia setMarkerSize (size _front);

		if (_HQ getVariable [QEGVAR(common,kIA),false]) exitWith {}
	};

	deleteMarker _ia
};

private _code2 = {
	params ["_HQ","_front","_isRectangle","_position","_xAxis","_yAxis","_direction","_code"];

	private _alive = true;

	waitUntil {
		sleep 5;

		_alive = true;

		switch (true) do {
			case (isNil "_HQ") : {_alive = false};
			case (isNull _HQ) : {_alive = false};
			case (({alive _x} count (units _HQ)) < 1) : {_alive = false};
		};

		private _debug = _HQ getVariable QEGVAR(common,debug);

		(!(isNil "_debug") || !(_alive))
	};

	if !(_alive) exitWith {};

	if (_HQ getVariable [QEGVAR(common,debug),false]) then {
		_shape = "ELLIPSE";
		if (_isRectangle) then {_shape = "RECTANGLE"};

		_ia = "markFront" + (str _HQ);
		_ia = createMarker [_ia,_position];
		_ia setMarkerColorLocal "ColorRed";
		_ia setMarkerShapeLocal _shape;
		_ia setMarkerSizeLocal [_xAxis, _yAxis];
		_ia setMarkerDirLocal _direction;
		_ia setMarkerBrushLocal "Border";
		_ia setMarkerColor "ColorKhaki";
		_SCRname = "Front2";
		[[_HQ, _front, _ia], _code] call EFUNC(common,spawn)
	}
};


{
	private _front = _x getVariable [QEGVAR(common,front), objNull];
	if !(isNull _front) then {
		private _position = position _front;
		private _area = triggerArea _front;

		_area params ["_xAxis","_yAxis","_direction","_isRectangle"];

		_front = createLocation ["Name", _position, _xAxis, _yAxis];
		_front setDirection _direction;
		_front setRectangular _isRectangle;

		_x setVariable [QEGVAR(common,front), _front];

		[[_x, _front, _isRectangle, _position, _xAxis, _yAxis, _direction, _code], _code2] call EFUNC(common,spawn);
	};
} forEach GVAR(allHQ);
