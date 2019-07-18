SHELL=bash
assertEnv=@if [ -z $${$(strip $1)+x} ]; then >&2 echo "You need to define \$$$(strip $1)"; exit 1; fi

demo:
	$(call assertEnv, PARENT_ZONE)
	terraform init
	terraform apply -auto-approve -var 'parent_zone=$(PARENT_ZONE)'
	ssh -o StrictHostKeyChecking=no root@demo.$(PARENT_ZONE) hostname

clean:
	$(call assertEnv, PARENT_ZONE)
	terraform destroy -auto-approve -var 'parent_zone=$(PARENT_ZONE)'
