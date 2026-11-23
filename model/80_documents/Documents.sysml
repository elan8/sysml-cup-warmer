/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 *
 * The verification report of the cup warmer. The requirements are read from the model and the verdicts from the file
 * that Run42 wrote (build/verdicts.json, see scripts/verify.sh), so the report cannot drift from either.
 */
package CupWarmerDocuments {
  private import Elan8::Documents::*;
  private import StandardViewDefinitions::*;

  view report {
    @Document {
      title = "Cup Warmer";
      subtitle = "Verification Report";
      organization = "Elan8";
      number = "CW-VR-001";
      revision = "A";
      status = "Example";
      template = "template";
    }

    view purpose {
      @Section { title = "Purpose"; }
      doc /* This report shows what was verified about the cup warmer design and what the simulation found. Every row
             comes from the SysML v2 model, and every verdict from a Run42 run of the case that verifies the requirement. */
    }

    view results {
      @Section { title = "Requirements and verdicts"; }
      @Table {
        columns = "ID = id, Requirement = text, Verified by = verified-by, Verdict = verified-by / verdict, Detail = verified-by / verdict-detail";
        kind = "requirement";
        verdicts = "../../build/verdicts.json";
        caption = "The requirements of the cup warmer and the verdict of the case that verifies each.";
      }
      expose CupWarmer::*;
    }

    view method {
      @Section { title = "Method"; }
      doc /* The plate is a Modelica model: heater power, heat capacity of the plate and cup, and heat loss to the air.
             The controller is a SysML v2 state machine that senses the temperature once a second. A case runs the
             controller against the plate and checks an assertion at the end of its stimulus. The sensor-fault case
             uses a plate whose control sensor reads 30 K too low. */
    }

    view limits {
      @Section { title = "Limits of this evidence"; }
      doc /* The plate model is a first estimate with assumed parameters, not measured values. The verdicts hold for this
             model and these parameters only. They are simulation results, not test results of a real appliance, and they
             do not show compliance with any standard. */
    }
  }
}
