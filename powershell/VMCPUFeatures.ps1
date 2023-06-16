Function Get-VMCPUFeatures {
<#
    .DESCRIPTION Function to retreive and decode CPUID features for a vSphere VM
    .NOTES  Author:  William Lam
    .NOTES  Site:    www.williamlam.com
    .PARAMETER VMName
        Name of the Virtual Machine
    .PARAMETER Translate
        Translate the CPUID feature to human friendly label
#>
    param(
        [Parameter(Mandatory=$true)][String]$VMName,
        [Switch]$Translate
    )

    Function Get-CpuIdMapping {
        param(
            [Parameter(Mandatory=$true)]$Features,
            [Switch]$Translate
        )

        # CPUID mapping as of vSphere 8.0 Update 1
        $cpuIdMapping=@{"cpuid.intel"="Intel";"cpuid.amd"="AMD";"cpuid.via"="VIA";"cpuid.cyrix"="Cyrix";"cpuid.family"="CPU Family";"cpuid.model"="CPU Model";"cpuid.stepping"="CPU Stepping";"cpuid.numlevels"="CPU Number of Levels";"cpuid.num_ext_levels"="CPU Number of Extended Levels";"cpuid.3dnow"="3DNow!";"cpuid.3dnowplus"="AMD extensions to 3DNow! (3DNowExt)";"cpuid.3dnprefetch"="3DNow! PREFETCH and PREFETCHW";"cpuid.abm"="Advanced Bit Manipulation (ABM)";"cpuid.adx"="Multi-Precision Add-Carry Instruction Extensions (ADX)";"cpuid.aes"="AES instructions (AES-NI)";"cpuid.always_serializing_lfence"="Always serializing LFENCE";"cpuid.amd_fast_short_cmpsb"="Fast short CMPSB";"cpuid.amd_fast_short_stosb"="Fast short STOSB";"cpuid.amx_bf16"="Advanced Matrix Extensions support for BF16";"cpuid.amx_int8"="Advanced Matrix Extensions support for INT8";"cpuid.amx_tile"="Advanced Matrix Extensions Tile Architecture";"cpuid.avx"="Advanced Vector Extensions (AVX)";"cpuid.avx2"="Advanced Vector Extensions 2 (AVX2)";"cpuid.avx_vnni"="Vector Neural Network Instructions";"cpuid.avx512bf16"="Advanced Vector Extensions 512 support for BF16 (AVX512BF16)";"cpuid.avx512bitalg"="Advanced Vector Extensions 512 Bit Algorithms (AVX512BITALG)";"cpuid.avx512bw"="Advanced Vector Extensions 512 Byte and Word Instructions (AVX512BW)";"cpuid.avx512cd"="Advanced Vector Extensions 512 Confict Detection (AVX512CD)";"cpuid.avx512dq"="Advanced Vector Extensions 512 Doubleword and Quadword (AVX512DQ)";"cpuid.avx512er"="Advanced Vector Extensions 512 Exponential and Reciprocal (AVX512ER)";"cpuid.avx512f"="Advanced Vector Extensions 512 Foundation (AVX512F)";"cpuid.avx512fp16"="Advanced Vector Extensions 512 support for FP16 (AVX512FP16)";"cpuid.avx512ifma"="Advanced Vector Extensions 512 Integer Fused Multiply Add (AVX512IFMA)";"cpuid.avx512pf"="Advanced Vector Extensions 512 Prefetch Instructions (AVX512PF)";"cpuid.avx512vbmi"="Advanced Vector Extensions 512 Vectorized Bit Manipulation (AVX512VBMI)";"cpuid.avx512vbmi2"="Advanced Vector Extensions 512 Vectorized Bit Manipulation 2.0 (AVX512VBMI2)";"cpuid.avx512vl"="Advanced Vector Extensions 512 Vector Length Extensions (AVX512VL)";"cpuid.avx512vnni"="Advanced Vector Extensions 512 Vector Neural Network Instructions (AVX512VNNI)";"cpuid.avx512vpopcntdq"="Advanced Vector Extensions 512 Vector Population Count Instructions (AVX512VPOPCNTDQ";"cpuid.avx512vp2intersect"="Advanced Vector Extensions 512 Vector Pair Intersection to a Pair of Mask Registers (AVX512VP2INTERSECT)";"cpuid.automatic_ibrs"="Automatic IBRS";"cpuid.bmi1"="Bit Manipulation Instruction (BMI) Set 1";"cpuid.bmi2"="Bit Manipulation Instruction (BMI) Set 2";"cpuid.cet_ss"="Shadow Stacks";"cpuid.cldemote"="Cache Line Demote";"cpuid.clflushopt"="Optimized version of clflush (CLFLUSHOPT)";"cpuid.clwb"="Cache line write back (CLWB)";"cpuid.clzero"="CLZERO";"cpuid.cmpxchg16b"="CMPXCHG16B";"cpuid.cr8avail"="32-bit access to CR8";"cpuid.ds"="Debug Store (DS)";"cpuid.enfstrg"="Fast string operations (Enhanced REP MOVSB/STOSB)";"cpuid.extapicspc"="Extended APIC register space";"cpuid.f16c"="Half-precision conversion instructions (F16C)";"cpuid.fast_short_cmpsb_scasb"="Fast short CMPSB and SCASB";"cpuid.fast_short_repmov"="Fast short REP MOV";"cpuid.fast_short_stosb"="Fast short STOSB";"cpuid.fast_zero_movsb"="Fast zero-length MOVSB";"cpuid.fcmd"="FCMD";"cpuid.ffxsr"="FFXSR (Fast FXSAVE and Fast FXRSTOR)";"cpuid.fp_segment_zero"="FPU CS and FPU DS";"cpuid.fma"="FMA3";"cpuid.fma4"="FMA4";"cpuid.fsgsbase"="Instructions to read and write FS and GS base registers at any privilege level";"cpuid.gfni"="Galois Field New Instructions (GFNI)";"cpuid.hle"="Hardware Lock Elision (HLE)";"cpuid.ibpb"="Indirect Branch Prediction Barrier";"cpuid.ibrs"="Indirect Branch Restricted Speculation";"cpuid.invpcid"="Invalidate Process-Context Identifier (INVPCID)";"cpuid.lahf64"="64-bit support for LAHF/SAHF";"cpuid.leaf88_ibrs_same_mode"="IBRS provides same mode protection";"cpuid.leaf88_prefer_ibrs"="Prefer IBRS";"cpuid.leaf88_psfd"="Predictive Store Forward Disable";"cpuid.leaf88_ssbd_spec_ctrl"="Speculative Store Bypass Disable";"cpuid.lm"="Longmode";"cpuid.mdclear"="Microarchitectural Data clear";"cpuid.misaligned_sse"="Misaligned SSE";"cpuid.mmxext"="AMD extensions to MMX instructions";"cpuid.movbe"="MOVBE";"cpuid.movdiri"="Move Doubleword as Direct Store (MOVDIRI)";"cpuid.movdir64b"="Move 64 bytes as Direct Store (MOVDIR64B)";"cpuid.mpx"="Memory Protection Extensions (MPX)";"cpuid.mwait"="MWAIT";"cpuid.nx"="Execute Disable (XD) / No-Execute (NX)";"cpuid.pcid"="PCID";"cpuid.pclmulqdq"="Carryless multiply (PCLMULQDQ)";"cpuid.pdpe1gb"="1 GB pages (PDPE1GB)";"cpuid.pks"="Protection Keys for Supervisor-mode Pages (PKS)";"cpuid.pku"="Protection Keys For User-mode Pages (PKU)";"cpuid.popcnt"="POPCNT";"cpuid.pqe"="Platform Quality of Service Enforcement (PQE)";"cpuid.pqe_l3"="L3 Cache Allocation Technology (PQE_L3)";"cpuid.prefetchwt1"="Prefetch Vector Data Into Caches with Intent to Write and T1 Hint";"cpuid.psfd"="Predictive Store Forwarding Disable";"cpuid.psn"="Processor serial number (PSN)";"cpuid.rdpid"="RDPID";"cpuid.rdrand"="RDRAND";"cpuid.rdseed"="RDSEED";"cpuid.rdtscp"="RDTSCP";"cpuid.rtm"="Restricted Transactional Memory (RTM)";"cpuid.sha"="SHA extensions";"cpuid.serialize"="SERIALIZE";"cpuid.smap"="Supervisor Mode Access Prevention (SMAP)";"cpuid.smep"="Supervisor Mode Execution Protection (SMEP)";"cpuid.ss"="Self Snoop (SS)";"cpuid.ssbd"="Speculative Store Bypass Disable";"cpuid.sse3"="SSE3";"cpuid.sse41"="SSE4.1";"cpuid.sse42"="SSE4.2";"cpuid.sse4a"="SSE4a";"cpuid.ssse3"="SSSE3";"cpuid.stibp"="Single Thread Indirect Branch Predictor";"cpuid.svm"="AMD-V (SVM)";"cpuid.svm_decode_assists"="SVM decode-assists";"cpuid.svm_flush_by_asid"="SVM flush by ASID";"cpuid.svm_gmet"="Guest Mode Execute Trap (GMET)";"cpuid.svm_npt"="Rapid Virtualization Indexing (RVI)";"cpuid.svm_nrip"="SVM next RIP";"cpuid.svm_sss"="Supervisor Shadow Stacks";"cpuid.svm_vmcb_clean"="SVM VMCB Clean Bits";"cpuid.tbm"="Trailing Bit Manipulation (TBM)";"cpuid.umip"="User-Mode Instruction Prevention (UMIP)";"cpuid.upper_address_ignore"="Upper Address Ignore";"cpuid.wbnoinvd"="WBNOINVD";"cpuid.vaes"="Vectorized AES";"cpuid.vmx"="Intel VT-x";"cpuid.vpclmulqdq"="VPCLMULQDQ";"cpuid.xcr0_master_sse"="XSAVE SSE State";"cpuid.xcr0_master_ymm_h"="XSAVE YMM State";"cpuid.xcr0_master_bndcsr"="XSAVE of BNDCFGU and BNDSTATUS registers (BNDCSR)";"cpuid.xcr0_master_bndregs"="XSAVE of BND0-BND3 bounds registers (BNDREGS)";"cpuid.xcr0_master_hi16_zmm"="XSAVE of ZMM registers ZMM16-ZMM31";"cpuid.xcr0_master_opmask"="XSAVE of opmask registers k0-k7";"cpuid.xcr0_master_pkru"="XSAVE of Protection Key Register User State (PKRU)";"cpuid.xcr0_master_xtilecfg"="XSAVE of XTILECFG";"cpuid.xcr0_master_xtiledata"="XSAVE of XTILEDATA";"cpuid.xcr0_master_zmm_h"="XSAVE of high 256 bits of ZMM registers ZMM0-ZMM15";"cpuid.xfd"="Extended Feature Disable (XFD)";"cpuid.xgetbv_ecx1"="XGETBV with ECX 1";"cpuid.xsave"="XSAVE";"cpuid.xsave_xtilecfg_align"="Alignment of XTILECFG in XSAVE";"cpuid.xsave_xtilecfg_xfd"="Extended feature disable of XTILECFG";"cpuid.xsave_xtiledata_align"="Alignment of XTILEDATA in XSAVE";"cpuid.xsave_xtiledata_xfd"="Extended feature disable of XTILEDATA";"cpuid.xsavec"="XSAVEC (save extended states in compact format)";"cpuid.xsaveopt"="XSAVEOPT";"cpuid.xsaves"="XSAVES (save supervisor states)";"cpuid.xsaves_cet_s_sup_by_xss"="XSS support for supervisor CET state";"cpuid.xsaves_cet_u_sup_by_xss"="XSS support for user CET state";"cpuid.xop"="Extended Operations (XOP)";"cpuid.xss_master_cet_s"="XSAVES of supervisor CET state";"cpuid.xss_master_cet_u"="XSAVES of user CET state";}

        $results = @()

        # Loop through each CPU feature and attempt translation using $cpuIdMapping if it exists
        foreach ($feature in $features) {
            if($Translate) {
                $key = $cpuIdMapping[$feature.Key] ? $cpuIdMapping[$feature.Key] : $feature.Key
            } else {
                $key = $feature.key
            }

            $tmp = [pscustomobject] @{
                Key = $key;
                Value = $feature.Value;
            }

            $results += $tmp
        }

        return $results | Sort-Object -Property Key
    }

    $vm = Get-VM $vmName

    # PerEVC enable or manual masking
    if($vm.ExtensionData.Runtime.FeatureMask -ne $null) {
        $features = $vm.ExtensionData.Runtime.FeatureMask
        if($Translate) {
            Get-CpuIdMapping -Features $features -Translate
        } else {
            Get-CpuIdMapping -Features $features
        }
    # VM Powered on
    } elseif($vm.ExtensionData.Runtime.FeatureRequirement -ne $null) {
        $features = $vm.ExtensionData.Runtime.FeatureRequirement
        if($Translate) {
            Get-CpuIdMapping -Features $features -Translate
        } else {
            Get-CpuIdMapping -Features $features
        }
    } else {
        Write-Host "FeatureRequirement and FeatureMask is not available, VM needs to be powered on to retrieve CPU instructions"
    }
}