($base[0].agentLifetimeDispatchFixed == null) and
(.agentLifetimeDispatchFixed == null) and
(.storageBinary == $storeHelper and .signatureBinary == $signatureHelper) and
(.providerServices == ([7950, 7951] | map(
  {providerResourceId:.,tariff:{version:"1",model:"bonsai2-27b-ptq1",routes:{
    user:{perOp:"0"},
    pool:{perOp:"0",inputMicroPerMillion:"0",outputMicroPerMillion:"0"},
    homelab:{perOp:"0",inputMicroPerMillion:"0",outputMicroPerMillion:"0"}}}}))) and
(del(.storageBinary,.signatureBinary,.providerServices,.agentLifetimeDispatchFixed) ==
 ($base[0] | del(.providerServices,.storageBinary,.signatureBinary,
                 .agentLifetimeDispatchFixed)))
