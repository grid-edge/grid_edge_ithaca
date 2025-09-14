# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class AddOutputs < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'add_outputs'
  end

  # human readable description
  def description
    return 'This measure adds output variables and creates required output reports'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'This measure adds output variables and creates required output reports'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # # the name of the space to add to the model
    # space_name = OpenStudio::Measure::OSArgument.makeStringArgument('space_name', true)
    # space_name.setDisplayName('New space name')
    # space_name.setDescription('This name will be used as the name of the new space.')
    # args << space_name

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)  # Do **NOT** remove this line

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

  
    def sanitize_ems_name(name)
      name.gsub(/[^A-Za-z0-9_]/, '')[0..59] # Remove special chars, limit to 60 chars
    end

    # Add output variables for Facility Total Purchased Electricity Energy, Facility Total Surplus Electricity Energy,
    # Facility Net Purchased Electricity Energy, Facility Total Produced Electricity Energy in Wh and J.
    # These are added regardless of whether a battery is present or not.
    variables = [
      'Facility Total Purchased Electricity Energy',
      'Facility Total Surplus Electricity Energy',
      'Facility Net Purchased Electricity Energy',
      'Facility Total Produced Electricity Energy'
    ]

    variables.each do |var_name|

      glob_name = sanitize_ems_name(var_name)

      #  Output variable
      out_var = OpenStudio::Model::OutputVariable.new(var_name, model)
      out_var.setName(glob_name)
      out_var.setReportingFrequency('Timestep')

      #  EMS Sensor
      sensor_name = glob_name + "_Sensor"
      sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var_name)
      sensor.setName(sensor_name)
      sensor.setKeyName("Whole Building")

      #  EMS Global Variable (in Wh)
      glob_name_kwh = glob_name + "_kWh"
      glob = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, glob_name_kwh)

      #  EMS Global Variable (in J)
      glob_name_j = glob_name + "_J"
      glob_j = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, glob_name_j)

      #  EMS Program (J to Wh conversion)
      prog_name = "Convert_" + glob_name
      ems_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      ems_program.setName(prog_name)
      ems_program.addLine("SET #{glob_name_j} = #{sensor_name}")
      ems_program.addLine("SET #{glob_name_kwh} = #{sensor_name} / 3600 / 1000") # convert to kWh

      #  Program Calling Manager
      pcm_name = "Run_" + glob_name
      pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      pcm.setName(pcm_name)
      pcm.setCallingPoint("EndOfSystemTimestepBeforeHVACReporting")
      pcm.addProgram(ems_program)

      #  EMS OutputVariable for Wh value
      ems_output = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, glob)
      ems_output.setName("EMS_#{glob_name}_kWh")
      ems_output.setUpdateFrequency("Timestep")

      #  OutputVariable Wh(Alfalfa-readable)
      out_var_kwh = OpenStudio::Model::OutputVariable.new("EMS_#{glob_name}_kWh", model)
      out_var_kwh.setName("#{glob_name}_kWh")
      out_var_kwh.setReportingFrequency("Timestep")
      out_var_kwh.setKeyValue("EMS")
      out_var_kwh.setExportToBCVTB(true)

      #  EMS OutputVariable for J value
      ems_output = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, glob_j)
      ems_output.setName("EMS_#{glob_name}_J")
      ems_output.setUpdateFrequency("Timestep")

      #  OutputVariable J(Alfalfa-readable)
      out_var_j = OpenStudio::Model::OutputVariable.new("EMS_#{glob_name}_J", model)
      out_var_j.setName("#{glob_name}_J")
      out_var_j.setReportingFrequency("Timestep")
      out_var_j.setKeyValue("EMS")
      out_var_j.setExportToBCVTB(true)
    end


    # Add output meters for building, facility in Wh and J, since these parameters do not have output variables.
    # These are added regardless of whether a battery is present or not.
    meters = [
      'Electricity:Building',
      'Electricity:Facility',
    ]

    meters.each do |meter_name|

      meter_name_santized = sanitize_ems_name(meter_name)

      #  Output:Meter
      out_meter = OpenStudio::Model::OutputMeter.new(model)
      out_meter.setName(meter_name_santized)
      out_meter.setReportingFrequency('Timestep')

      #  EMS Sensor
      sensor_name = meter_name_santized + "_Sensor"
      sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, meter_name)
      sensor.setName(sensor_name)

      #  EMS Global Variable (in J)
      glob_name_J = meter_name_santized + "_J"
      glob_J = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, glob_name_J)

      #  EMS Global Variable (in Wh)
      glob_name_kWh = meter_name_santized + "_kWh"
      glob_kWh = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, glob_name_kWh)

      #  EMS Program (J to Wh conversion)
      prog_name = "Convert_" + meter_name_santized
      ems_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      ems_program.setName(prog_name)
      ems_program.addLine("SET #{glob_name_J} = #{sensor_name}") # add sensor value as well
      ems_program.addLine("SET #{glob_name_kWh} = #{sensor_name} / 3600 / 1000") # convert to kWh

      #  Program Calling Manager
      pcm_name = "Run_" + meter_name_santized
      pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      pcm.setName(pcm_name)
      pcm.setCallingPoint("EndOfSystemTimestepBeforeHVACReporting")
      pcm.addProgram(ems_program)

      #  EMS OutputVariable J
      ems_output = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, glob_J)
      ems_output.setName("EMS_#{glob_name_J}")
      ems_output.setUpdateFrequency("Timestep")

      #  EMS OutputVariable kWh
      ems_output_sensor = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, glob_kWh)
      ems_output_sensor.setName("EMS_#{glob_name_kWh}")
      ems_output_sensor.setUpdateFrequency("Timestep")

      #  OutputVariable J (Alfalfa-readable)
      out_var_J = OpenStudio::Model::OutputVariable.new("EMS_#{glob_name_J}", model)
      out_var_J.setName("#{glob_name_J}")
      out_var_J.setReportingFrequency("Timestep")
      out_var_J.setKeyValue("EMS")
      out_var_J.setExportToBCVTB(true)

      #  OutputVariable kWh (Alfalfa-readable)
      out_var_kWh = OpenStudio::Model::OutputVariable.new("EMS_#{glob_name_kWh}", model)
      out_var_kWh.setName("#{glob_name_kWh}")
      out_var_kWh.setReportingFrequency("Timestep")
      out_var_kWh.setKeyValue("EMS")
      out_var_kWh.setExportToBCVTB(true)
    end

    # Request output reports
    # output tables as HTML and CSV
    # octs = model.getOutputControlTableStyle
    # octs.setColumnSeparator('CommaAndHTML')

    # add output control files
    ocf = model.getOutputControlFiles
    ocf.setOutputCSV(true)
    ocf.setOutputMTR(true)
    ocf.setOutputESO(true)
    ocf.setOutputEIO(false)
    ocf.setOutputTabular(true)
    ocf.setOutputSQLite(false)
    ocf.setOutputJSON(false)
    ocf.setOutputAUDIT(false)
    ocf.setOutputZoneSizing(false)
    ocf.setOutputSystemSizing(false)
    ocf.setOutputDXF(false)
    ocf.setOutputBND(false)
    ocf.setOutputRDD(true)
    ocf.setOutputMDD(true)
    ocf.setOutputMTD(false)
    ocf.setOutputSHD(false)
    ocf.setOutputDFS(false)
    ocf.setOutputGLHE(false)
    ocf.setOutputDelightIn(false)
    ocf.setOutputDelightELdmp(false)
    ocf.setOutputDelightDFdmp(false)
    ocf.setOutputEDD(false)
    ocf.setOutputDBG(false)
    ocf.setOutputPerfLog(false)
    ocf.setOutputSLN(false)
    ocf.setOutputSCI(false)
    ocf.setOutputWRL(false)
    ocf.setOutputScreen(false)
    ocf.setOutputExtShd(false)
    ocf.setOutputTarcog(false)

    return true
  end
end

# register the measure to be used by the application
AddOutputs.new.registerWithApplication
