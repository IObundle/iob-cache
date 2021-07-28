#######################################################
#
# IOB-SoC: Encounter Place & Route Script              
#
#######################################################

#import verilog
set init_verilog ../synth/system_synth.v

#top level module
set init_design system


#lef libraries
set tech_lef [glob /opt/ic_tools/pdk/faraday/umc130/LL/fsc0l_d/2009Q2v3.0/GENERIC_CORE/BackEnd/lef/*.lef]
set bootrom_lef [glob ../memory/bootrom/*.lef]
set bootram_lef [glob ../memory/bootram/*.lef]

set init_lef_file [list $tech_lef $bootrom_lef $bootram_lef]

set init_mmmc_file Default.view

set init_import_mode {-treatUndefinedCellAsBbox 0 -keepEmptyModule 1 }

set init_gnd_net GND
set init_pwr_net VDD

###################################################################################
# top
set dbgGPSAutoCellFunction 1
init_design

set BASENAME system

###################################################################################
# floor plan 
#setDesignMode -process 130

puts "-------------Floorplanning---------------"
#
# Make a floorplan - this works fine for projects that are all
# standard cells and include no blocks that need hand placement...
set aspect 0.9987802253
set usepct 0.698911
set coregap 25.0
set rowgap 10.0

setDrawView fplan
setFPlanRowSpacingAndType $rowgap 2
floorPlan -site core -r $aspect $usepct \
$coregap $coregap $coregap $coregap
fit
#
# Save design so far
saveDesign ${BASENAME}_fplan.enc
saveFPlan ${BASENAME}.fp
puts "--------------Floorplanning done----------"



floorPlan -site core -adjustToSite -r 0.9987802253 0.698911 25.0 25.0 25.0 25.0
addRing -center 1 -stacked_via_top_layer metal8 -around cluster -jog_distance 0.4 -threshold 0.4 -nets {VDD GND} -stacked_via_bottom_layer metal1 -layer {bottom metal1 top metal1 right metal2 left metal2} -width 10 -spacing 1 -offset 0.4

set sprCreateIeStripeNets {}
set sprCreateIeStripeLayers {}
set sprCreateIeStripeWidth 10.0
set sprCreateIeStripeSpacing 2.0
set sprCreateIeStripeThreshold 1.0

addStripe -block_ring_top_layer_limit metal3 \
-max_same_layer_jog_length 0.8 \
-padcore_ring_bottom_layer_limit metal1 \
-number_of_sets 6 \
-stacked_via_top_layer metal8 \
-padcore_ring_top_layer_limit metal3 \
-spacing 1 \
-xleft_offset 20 \
-merge_stripes_value 0.4 \
-layer metal2 -block_ring_bottom_layer_limit metal1 \
-width 8 -nets {GND VDD} \
-stacked_via_bottom_layer metal1 \
-break_stripes_at_block_rings 1

#special route
sroute \
-connect {} \
-layerChangeRange { metal1 metal8 } \
-blockPinTarget { nearestTarget } \
-checkAlignedSecondaryPin 1 \
-allowJogging 1 \
-crossoverViaBottomLayer metal1 \
-allowLayerChange 1 \
-targetViaTopLayer metal8 \
-crossoverViaTopLayer metal8 \
-targetViaBottomLayer metal1 \
-nets { GND VDD }

#
setPlaceMode -reset
setPlaceMode \
-congEffort auto \
-timingDriven 1 \
-modulePlan 1 \
-clkGateAware 1 \
-powerDriven 0 \
-ignoreScan 1 \
-reorderScan 0 \
-ignoreSpare 1 \
-placeIOPins 1 \
-moduleAwareSpare 0 \
-checkPinLayerForAccess {  1 } \
-preserveRouting 0 \
-rmAffectedRouting 0 \
-checkRoute 0 \
-swapEEQ 0 \
-fp false

placeDesign -prePlaceOpt

timeDesign -preCTS
setOptMode -fixCap true -fixTran true -fixFanoutLoad false
optDesign -preCTS
#trialRoute -maxRouteLayer 8


#Synthesizing a Clock Tree
#setCTSMode -engine ck
createClockTreeSpec \
-bufferList {BUFCKELD BUFCKGLD BUFCKHLD BUFCKILD BUFCKJLD BUFCKKLD BUFCKLLD BUFCKMLD BUFCKNLD BUFCKQLD INVCKDLD INVCKGLD INVCKHLD INVCKILD INVCKJLD INVCKKLD INVCKLLD INVCKMLD INVCKNLD INVCKQLD CKLDLD DELCKLD GCKETCLD GCKETELD GCKETHLD GCKETKLD} \
-file Clock.ctstch
clockDesign -specFile Clock.ctstch -outDir clock_report
#setAnalysisMode -analysisType onChipVariation
#setAnalysisMode -cppr both
#update_io_latency
timeDesign -postCTS
optDesign -postCTS
#redirect -quiet {set honorDomain [getAnalysisMode -honorClockDomains]} > /dev/null
timeDesign -postCTS -hold -pathReports -slackReports -numPaths 50 -prefix system_postCTS -outDir timingReports

setOptMode -fixCap true -fixTran true -fixFanoutLoad false
optDesign -postCTS -hold
timeDesign -postCTS
optDesign -postCTS -drv

#route design 
setNanoRouteMode -quiet -routeWithTimingDriven 1
setNanoRouteMode -quiet -routeWithSiDriven 1
setNanoRouteMode -quiet -routeTopRoutingLayer default
setNanoRouteMode -quiet -routeBottomRoutingLayer default
setNanoRouteMode -quiet -drouteEndIteration default
setNanoRouteMode -quiet -routeWithTimingDriven true
setNanoRouteMode -quiet -routeWithSiDriven true
routeDesign -globalDetail

setExtractRCMode -engine postRoute
setExtractRCMode -effortLevel low

timeDesign -postRoute
timeDesign -postRoute -hold

setDelayCalMode -engine default -SIAware true

optDesign -postRoute
optDesign -postRoute -hold

setDelayCalMode -SIAware false
setDelayCalMode -engine signalStorm
timeDesign -signoff -si
timeDesign -signoff -si -hold

write_sdf system.sdf
reportNetStat
reportGateCount
summaryReport
saveDesign system_par.enc
saveNetlist system_par.v
