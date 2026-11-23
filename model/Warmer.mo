// SPDX-FileCopyrightText: 2026 Elan8
// SPDX-License-Identifier: MIT
within ;
package Warmer
  connector Heat
    Real temperature(unit="K");
  end Heat;
  // A heated plate under a cup: the heater adds power, the plate and cup lose heat to the air.
  model Plate
    parameter Real heaterPower(unit="W") = 40;
    parameter Real capacity(unit="J/K") = 180;
    parameter Real loss(unit="W/K") = 0.35;
    parameter Real ambient(unit="K") = 293.15;
    input Real command;
    Heat heat;
    Real temperature(unit="K", start=293.15, fixed=true);
  equation
    capacity * der(temperature) = heaterPower * command - loss * (temperature - ambient);
    heat.temperature = temperature;
  end Plate;
  // The control sensor: it reads the plate temperature plus an error, which is zero unless the sensor is faulty.
  model Probe
    parameter Real offset(unit="K") = 0;
    Heat heat;
    Real reading(unit="K");
  equation
    reading = heat.temperature + offset;
  end Probe;
end Warmer;
