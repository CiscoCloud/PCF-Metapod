require 'vm_shepherd/vsphere_manager'

module VmShepherd
  RSpec.describe VsphereManager do
    let(:host) { 'FAKE_VSPHERE_HOST' }
    let(:username) { 'FAKE_USERNAME' }
    let(:password) { 'FAKE_PASSWORD' }
    let(:datacenter_name) { 'FAKE_DATACENTER_NAME' }
    let(:vm1) { instance_double(RbVmomi::VIM::VirtualMachine, name: 'vm_name1', resourcePool: instance_double(RbVmomi::VIM::ResourcePool, name: 'first_resource_pool')) }
    let(:vm2) { instance_double(RbVmomi::VIM::VirtualMachine, name: 'vm_name2', resourcePool: instance_double(RbVmomi::VIM::ResourcePool, name: 'second_resource_pool')) }
    let(:vm3) { instance_double(RbVmomi::VIM::VirtualMachine, name: 'vm_name3', resourcePool: instance_double(RbVmomi::VIM::ResourcePool, name: 'second_resource_pool')) }
    let(:vms) { [vm1, vm2, vm3] }

    subject(:vsphere_manager) do
      manager = VsphereManager.new(host, username, password, datacenter_name)
      manager.logger = Logger.new(StringIO.new)
      manager
    end

    it 'loads' do
      expect { vsphere_manager }.not_to raise_error
    end

    describe 'destroy' do
      let(:search_index) { instance_double(RbVmomi::VIM::SearchIndex) }
      let(:service_content) { instance_double(RbVmomi::VIM::ServiceContent, searchIndex: search_index)}
      let(:connection) { instance_double(RbVmomi::VIM, serviceContent: service_content)}
      let(:ip_address) { '127.0.0.1' }

      before do
        allow(vsphere_manager).to receive(:connection).and_return(connection)
        allow(search_index).to receive(:FindAllByIp).with(ip: ip_address, vmSearch: true).and_return(vms)
      end

      it 'destroys the VM that matches the given ip address and resource pool' do
        expect(vsphere_manager).to receive(:power_off_vm).with(vm2)
        expect(vsphere_manager).to receive(:destroy_vm).with(vm2)

        expect(vsphere_manager).to receive(:power_off_vm).with(vm3)
        expect(vsphere_manager).to receive(:destroy_vm).with(vm3)

        vsphere_manager.destroy(ip_address, 'second_resource_pool')
      end

      it 'destroys the VM that matches the given ip address only when resource pool nil' do
        expect(vsphere_manager).to receive(:power_off_vm).with(vm1)
        expect(vsphere_manager).to receive(:destroy_vm).with(vm1)

        expect(vsphere_manager).to receive(:power_off_vm).with(vm2)
        expect(vsphere_manager).to receive(:destroy_vm).with(vm2)

        expect(vsphere_manager).to receive(:power_off_vm).with(vm3)
        expect(vsphere_manager).to receive(:destroy_vm).with(vm3)

        vsphere_manager.destroy(ip_address, nil)
      end

      context 'when there are no vms with that IP address' do
        let(:vms) { [] }

        it 'does not explode' do
          expect(vsphere_manager).not_to receive(:power_off_vm)
          expect(vsphere_manager).not_to receive(:destroy_vm)

          vsphere_manager.destroy(ip_address, 'second_resource_pool')
        end
      end

      context 'when there are no vms in that resource pool' do
        it 'does not explode' do
          expect(vsphere_manager).not_to receive(:power_off_vm)
          expect(vsphere_manager).not_to receive(:destroy_vm)

          vsphere_manager.destroy(ip_address, 'other_resource_pool')
        end
      end
    end

    describe 'destroy_vm' do
      let(:destroy_task) { instance_double(RbVmomi::VIM::Task) }

      before do
        allow(vm1).to receive(:Destroy_Task).and_return(destroy_task)
      end

      it 'runs the Destroy_Task and waits for completion' do
        expect(destroy_task).to receive(:wait_for_completion)

        vsphere_manager.destroy_vm(vm1)
      end
    end
  end
end
