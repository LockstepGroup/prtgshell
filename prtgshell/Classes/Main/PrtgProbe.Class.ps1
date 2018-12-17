class PrtgProbe {
    [int]$ObjectId
    [System.Xml.XmlElement]$Xml

    [bool]$Active

    [string]$Notification
    [string]$Interval
    [int]$IntervalRaw
    [string]$Access
    [int]$AccessRaw
    [string]$Dependency
    [string]$DependencyRaw
    [string]$ProbeGroupDevice
    [int]$ProbeGroupDeviceRaw
    [string]$Status
    [int]$StatusRaw
    [string]$Message
    [string]$MessageRaw
    [int]$Priority
    [int]$totalSensors
    [int]$totalSensorsRaw
    [string]$Favorite
    [string]$FavoriteRaw
    [string]$Schedule
    [string]$Condition
    [string]$ConditionRaw
    [string]$BaseLink
    [string]$BaseLinkRaw
    [int]$ParentId
    [int]$GroupNumber
    [int]$GroupNumberRaw
    [int]$DeviceNumber
    [int]$DeviceNumberRaw

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
    PrtgProbe() {
    }

    # Contructor that takes return from prtgtabledata
    PrtgProbe([System.Xml.XmlElement]$DeviceXml) {
        $this.Xml = $DeviceXml
        $this.ObjectId = $DeviceXml.objid
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

        $this.Notification = $DeviceXml.notifiesx
        $this.Interval = $DeviceXml.intervalx
        $this.IntervalRaw = $DeviceXml.intervalx_raw
        $this.Access = $DeviceXml.access
        $this.AccessRaw = $DeviceXml.access_raw
        $this.Dependency = $DeviceXml.dependency
        $this.DependencyRaw = $DeviceXml.dependency_raw
        $this.ProbeGroupDevice = $DeviceXml.probegroupdevice
        $this.ProbeGroupDeviceRaw = $DeviceXml.probegroupdevice_raw
        $this.Status = $DeviceXml.status
        $this.StatusRaw = $DeviceXml.status_raw
        $this.Message = $DeviceXml.message
        $this.MessageRaw = $DeviceXml.message_raw
        $this.Priority = $DeviceXml.priority
        $this.totalSensors = $DeviceXml.totalsens
        $this.totalSensorsRaw = $DeviceXml.totalsens_raw
        $this.Favorite = $DeviceXml.favorite
        $this.FavoriteRaw = $DeviceXml.favorite_raw
        $this.Schedule = $DeviceXml.schedule
        $this.Condition = $DeviceXml.condition
        $this.ConditionRaw = $DeviceXml.condition_raw
        $this.BaseLink = $DeviceXml.baselink
        $this.BaseLinkRaw = $DeviceXml.baselink_raw
        $this.ParentId = $DeviceXml.parentid
        $this.GroupNumber = $DeviceXml.groupnum
        $this.GroupNumberRaw = $DeviceXml.groupnum_raw
        $this.DeviceNumber = $DeviceXml.devicenum
        $this.DeviceNumberRaw = $DeviceXml.devicenum_raw
    }
}