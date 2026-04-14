require 'Items/ProceduralDistributions'

local function preDistributionMerge()

    if (SandboxVars.PhunSprinters or {}).AddToLoot then

        print("[PhunSprinters] Sensors being added to loot spawns...")

        -- ArmySurplusOutfit
        table.insert(ProceduralDistributions.list["ArmySurplusOutfit"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["ArmySurplusOutfit"].items, 1);

        -- ArmyStorageElectronics
        table.insert(ProceduralDistributions.list["ArmyStorageElectronics"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["ArmyStorageElectronics"].items, .05);

        -- ArmySurplusMisc
        table.insert(ProceduralDistributions.list["ArmySurplusMisc"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["ArmySurplusMisc"].items, 1);

        -- ElectronicStoreAppliances
        table.insert(ProceduralDistributions.list["ElectronicStoreAppliances"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["ElectronicStoreAppliances"].items, 2);

        -- ElectronicStoreMisc
        table.insert(ProceduralDistributions.list["ElectronicStoreMisc"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["ElectronicStoreMisc"].items, 2);

        -- FireDeptLockers
        table.insert(ProceduralDistributions.list["FireDeptLockers"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["FireDeptLockers"].items, 1);

        -- LockerArmyBedroom
        table.insert(ProceduralDistributions.list["LockerArmyBedroom"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["LockerArmyBedroom"].items, 1);

        -- MedicalStorageTools
        table.insert(ProceduralDistributions.list["MedicalStorageTools"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["MedicalStorageTools"].items, 1);

        -- SecurityLockers
        table.insert(ProceduralDistributions.list["SecurityLockers"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["SecurityLockers"].items, 0.5);

        -- PoliceLockers
        table.insert(ProceduralDistributions.list["PoliceLockers"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["PoliceLockers"].items, 1);

        -- StoreShelfMedical
        table.insert(ProceduralDistributions.list["StoreShelfMedical"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["StoreShelfMedical"].items, 5);

        -- TestingLab
        table.insert(ProceduralDistributions.list["TestingLab"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["TestingLab"].items, 1);

        -- ToolStoreTools
        table.insert(ProceduralDistributions.list["ToolStoreTools"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["ToolStoreTools"].items, 0.25);

        -- SurvivalGear
        table.insert(ProceduralDistributions.list["SurvivalGear"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["SurvivalGear"].items, 0.25);
        -- CrateCarpentry
        table.insert(ProceduralDistributions.list["CrateCarpentry"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["CrateCarpentry"].items, 1);

        -- CrateElectronics
        table.insert(ProceduralDistributions.list["CrateElectronics"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["CrateElectronics"].items, 1);

        -- GarageTools
        table.insert(ProceduralDistributions.list["GarageTools"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["GarageTools"].items, 3);

        -- MedicalClinicTools
        table.insert(ProceduralDistributions.list["MedicalClinicTools"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["MedicalClinicTools"].items, 3);

        -- ToolStoreAccessories
        table.insert(ProceduralDistributions.list["ToolStoreAccessories"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["ToolStoreAccessories"].items, 3);

        -- ArmyHangarTools
        table.insert(ProceduralDistributions.list["ArmyHangarTools"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["ArmyHangarTools"].items, 3);

        -- CrateTools
        table.insert(ProceduralDistributions.list["CrateTools"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["CrateTools"].items, 3);

        -- GymLockers
        table.insert(ProceduralDistributions.list["GymLockers"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["GymLockers"].items, 1);

        -- GunStoreShelf
        table.insert(ProceduralDistributions.list["GunStoreShelf"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["GunStoreShelf"].items, 1);

        -- BedroomSideTable
        -- table.insert(ProceduralDistributions.list["BedroomSideTable"].items, "Phun.Military_Sensor_Left");
        -- table.insert(ProceduralDistributions.list["BedroomSideTable"].items, 0.25);

        -- OfficeDrawers
        table.insert(ProceduralDistributions.list["OfficeDrawers"].items, "Phun.Military_Sensor_Left");
        table.insert(ProceduralDistributions.list["OfficeDrawers"].items, 0.5);
        -- glovebox
        table.insert(VehicleDistributions["GloveBox"].items, "Phun.Military_Sensor_Left");
        table.insert(VehicleDistributions["GloveBox"].items, 0.1);

        -- Suburbs
        table.insert(SuburbsDistributions["all"]["inventorymale"].items, "Phun.Military_Sensor_Left");
        table.insert(SuburbsDistributions["all"]["inventorymale"].items, 0.05);

        table.insert(SuburbsDistributions["all"]["inventoryfemale"].items, "Phun.Military_Sensor_Left");
        table.insert(SuburbsDistributions["all"]["inventoryfemale"].items, 0.05);
    else

        local sm = ScriptManager.instance
        local targets = {"Phun.Military_Sensor_Right", "Phun.Military_Sensor_Left"}
        for _, itemName in ipairs(targets) do
            local script = sm:getItem(itemName)
            if script then
                script:DoParam("OBSOLETE = true")
            end
        end

        print(
            "[PhunSprinters] Sensors will NOT be added to loot spawns. Enable 'Add To Loot' in the mod options to add them.")
    end
end
Events.OnPreDistributionMerge.Add(preDistributionMerge);

