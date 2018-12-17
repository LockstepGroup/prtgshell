class PrtgGroup {
    [int]$ObjectId
    [System.Xml.XmlElement]$Xml

    [string]$Probe
    [string]$Group
    [string]$Name
    [string]$DownSensor
    [int]$DownSensorRaw
    [string]$PartialDownSensor
    [int]$PartialDownSensorRaw
    [string]$DownAcknowledgedSensor
    [int]$DownAcknowledgedSensorRaw
    [string]$UpSensor
    [int]$UpSensorRaw
    [string]$WarningSensor
    [int]$WarningSensorRaw
    [string]$PausedSensor
    [int]$PausedSensorRaw
    [string]$UnusualSensor
    [int]$UnusualSensorRaw
    [string]$UndefinedSensor
    [int]$UndefinedSensorRaw

    ##################################### Constructors #####################################
    # Constructor with no parameter
    PrtgGroup() {
    }

    # Contructor that takes return from prtgtabledata
    PrtgGroup([System.Xml.XmlElement]$DeviceXml) {
        $this.Xml = $DeviceXml
        $this.ObjectId = $DeviceXml.objid
        $this.Probe = $DeviceXml.probe
        $this.Group = $DeviceXml.group
        $this.Name = $DeviceXml.name
        $this.DownSensor = $DeviceXml.downsens
        $this.DownSensorRaw = $DeviceXml.downsens_raw
        $this.PartialDownSensor = $DeviceXml.partialdownsens
        $this.PartialDownSensorRaw = $DeviceXml.partialdownsens_raw
        $this.DownAcknowledgedSensor = $DeviceXml.downacksens
        $this.DownAcknowledgedSensorRaw = $DeviceXml.downacksens_raw
        $this.UpSensor = $DeviceXml.upsens
        $this.UpSensorRaw = $DeviceXml.upsens_raw
        $this.WarningSensor = $DeviceXml.warnsens
        $this.WarningSensorRaw = $DeviceXml.warnsens_raw
        $this.PausedSensor = $DeviceXml.pausedsens
        $this.PausedSensorRaw = $DeviceXml.pausedsens_raw
        $this.UnusualSensor = $DeviceXml.unusualsens
        $this.UnusualSensorRaw = $DeviceXml.unusualsens_raw
        $this.UndefinedSensor = $DeviceXml.undefinedsens
        $this.UndefinedSensorRaw = $DeviceXml.undefinedsens_raw
    }
}