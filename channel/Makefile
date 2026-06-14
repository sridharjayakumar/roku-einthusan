ROKU_IP ?= 192.168.1.100
ROKU_USER ?= rokudev
ROKU_PASS ?= your_password
APP_NAME = einthusan
ZIP_FILE = $(APP_NAME).zip

.PHONY: package deploy clean

package:
	@echo "Packaging Roku channel..."
	@rm -f $(ZIP_FILE)
	@zip -r $(ZIP_FILE) manifest source/ components/ images/ -x "*.DS_Store" "Makefile"
	@echo "Created $(ZIP_FILE)"

deploy: package
	@echo "Deploying to Roku at $(ROKU_IP)..."
	@curl --user $(ROKU_USER):$(ROKU_PASS) --digest \
		-F "mysubmit=Install" \
		-F "archive=@$(ZIP_FILE)" \
		http://$(ROKU_IP)/plugin_install
	@echo "\nDeployed successfully!"

clean:
	@rm -f $(ZIP_FILE)
