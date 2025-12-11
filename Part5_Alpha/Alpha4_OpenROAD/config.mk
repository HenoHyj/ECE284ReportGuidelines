export PLATFORM         = ihp-sg13g2
export DESIGN_NAME      = core

export ADDITIONAL_LEFS += $(PLATFORM_DIR)/lef/RM_IHPSG13_1P_2048x64_c2_bm_bist.lef \
						  additional_tech_sram_files/RM_IHPSG13_1P_512x32_c2_bm_bist.lef

export ADDITIONAL_LIBS += $(PLATFORM_DIR)/lib/RM_IHPSG13_1P_2048x64_c2_bm_bist_typ_1p20V_25C.lib \
					      additional_tech_sram_files/RM_IHPSG13_1P_512x32_c2_bm_bist_typ_1p20V_25C.lib

export ADDITIONAL_GDS  += $(PLATFORM_DIR)/gds/RM_IHPSG13_1P_2048x64_c2_bm_bist.gds \
						  additional_tech_sram_files/RM_IHPSG13_1P_512x32_c2_bm_bist.gds

export VERILOG_FILES = verilog/*.v
export SDC_FILE 	 = constraint.sdc

export SYNTH_HIERARCHICAL = 1

export USE_FILL = 1

export CORE_UTILIZATION = 40
export PLACE_DENSITY    = 0.70
export TNS_END_PERCENT  = 100