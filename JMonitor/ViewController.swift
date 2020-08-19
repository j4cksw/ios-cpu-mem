//
//  ViewController.swift
//  JMonitor
//
//  Created by Prayoch Rujira on 19/8/2563 BE.
//  Copyright © 2563 j4cksw. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var cpuLabel: UILabel!
    @IBOutlet weak var memoryLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        cpuLabel.text = getCPULoadInfo()
        memoryLabel.text = getMemory()
    }

    func getCPULoadInfo()-> String{
        var cpuUsageInfo = ""
        var cpuInfo: processor_info_array_t!
        var prevCpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numPrevCpuInfo: mach_msg_type_number_t = 0
        var numCPUs: uint = 0
        let CPUUsageLock: NSLock = NSLock()
        var usage:Float32 = 0

        let mibKeys: [Int32] = [ CTL_HW, HW_NCPU ]
        mibKeys.withUnsafeBufferPointer() { mib in
            var sizeOfNumCPUs: size_t = MemoryLayout<uint>.size
            let status = sysctl(processor_info_array_t(mutating: mib.baseAddress), 2, &numCPUs, &sizeOfNumCPUs, nil, 0)
            if status != 0 {
                numCPUs = 1
            }
        }

        var numCPUsU: natural_t = 0
        let err: kern_return_t = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo);
        if err == KERN_SUCCESS {
            CPUUsageLock.lock()

            for i in 0 ..< Int32(numCPUs) {
                var inUse: Int32
                var total: Int32
                if let prevCpuInfo = prevCpuInfo {
                    inUse = cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_USER)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_USER)]
                        + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_SYSTEM)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_SYSTEM)]
                        + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_NICE)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_NICE)]
                    total = inUse + (cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_IDLE)]
                        - prevCpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_IDLE)])
                } else {
                    inUse = cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_USER)]
                        + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_SYSTEM)]
                        + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_NICE)]
                    total = inUse + cpuInfo[Int(CPU_STATE_MAX * i + CPU_STATE_IDLE)]
                }
                let coreInfo = Float(inUse) / Float(total)
                usage += coreInfo
                print(String(format: "Core: %u Usage: %f", i, Float(inUse) / Float(total)))
            }
            cpuUsageInfo = String(format:"%.2f",100 * Float(usage) / Float(numCPUs))
            CPUUsageLock.unlock()

            if let prevCpuInfo = prevCpuInfo {
                let prevCpuInfoSize: size_t = MemoryLayout<integer_t>.stride * Int(numPrevCpuInfo)
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevCpuInfo), vm_size_t(prevCpuInfoSize))
            }

            prevCpuInfo = cpuInfo
            numPrevCpuInfo = numCpuInfo

            cpuInfo = nil
            numCpuInfo = 0
        } else {
            print("Error!")
        }

        return cpuUsageInfo
    }

    func getMemory() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info))/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {

            task_info(mach_task_self_,
                      task_flavor_t(MACH_TASK_BASIC_INFO),
                      $0.withMemoryRebound(to: Int32.self, capacity: 1) { zeroPtr in
                        task_info_t(zeroPtr)
                      },
                      &count)

        }

        if kerr == KERN_SUCCESS {
            return "Memory in use (in bytes): \(info.resident_size)"
        }
        else {
            return "Error with task_info(): " +
                (String.init(validatingUTF8: mach_error_string(kerr)) ?? "unknown error")
        }
    }
}

