TESTSTACK   = cfg
SRCDIR      = .
DOCKERDIR   = docker
ARTIFACTORY = https://artifacts.industrysoftware.automation.siemens.com/artifactory
PLATFORM   ?= lnx64
# These are overridden by your local environment settings for TC_TOOLBOX, TC_LIB and TC_DATA
TC_TOOLBOX ?= /tc/toolbox
TC_LIB     ?= /app/tc/lib
TC_DATA    ?= /app/tc/data
TC_CFG_SERVICE_VERSION=tc12.4.0.0.2020021702
TC_CFG_SERVICE_HOME=$(TC_TOOLBOX)/$(PLATFORM)/tc_configurator
TC_CURL_VERSION	= tc_curl.12.20200120.00
TC_CURL_HOME	= $(TC_TOOLBOX)/$(PLATFORM)/cURL/$(TC_CURL_VERSION)
TC_CRYPTO_VERSION=5.0.4d
TC_CRYPTO_HOME	= $(TC_TOOLBOX)/$(PLATFORM)/TcCrypto/$(TC_CRYPTO_VERSION)
TC_RAPIDJSON_VERSION=4
TC_RAPIDJSON_HOME=$(TC_TOOLBOX)/RapidJSON/$(TC_RAPIDJSON_VERSION)

HAZELCAST_HOME=$(TC_TOOLBOX)/$(PLATFORM)/hazelcast
HAZELCAST_CPPCLIENT_VERSION=3.10.1
HAZELCAST_CPPCLIENT_HOME=$(HAZELCAST_HOME)/cpp-client-$(HAZELCAST_CPPCLIENT_VERSION)

#OPTFLAGS	= -g
OPTFLAGS	= -O
CPPFLAGS=-std=c++11 $(OPTFLAGS) -fpermissive -Wno-deprecated -D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS -DIPLIB=libvariabilityadaptor \
	-I$(TC_CRYPTO_HOME)/include \
	-I$(TC_CURL_HOME)/include \
	-I$(TC_CFG_SERVICE_HOME)/include \
	-I$(TC_RAPIDJSON_HOME) \
	-I$(TC_CFG_SERVICE_HOME)/include/syss \
	-I$(HAZELCAST_CPPCLIENT_HOME)/Linux_64/external/include \
	-I$(HAZELCAST_CPPCLIENT_HOME)/Linux_64/hazelcast/include \
	-Isrc
#LDFLAGS=-g
LDFLAGS	=
# TODO recompile hazelcast cpp lib without ssl references
LDLIBS	=-lpthread -lrt \
	-L$(HAZELCAST_CPPCLIENT_HOME)/Linux_64/hazelcast/lib \
	-lHazelcastClient3.10.1_64 \
	-L$(TC_CFG_SERVICE_HOME)/lib \
	-L$(TC_CRYPTO_HOME)/bin_64_cpp11 \
	-L$(TC_CURL_HOME)/libgcc48 \
	-lbase_utils \
	-lbooleanmath \
	-lconfigurator \
	-lconstraintsolver \
	-lFSCNativeClientProxy64 \
	-licudata641_X_17 \
	-licuuc641_X_17 \
	-lmld \
	-lnls \
	-lpoco \
	-lsyss \
	-lTcCrypto \
	-lTcCryptoStd \
	-lTcCryptoUtil \
	-ltccurl \
	-lvariabilityadaptor \
	-lxerces321_X_17 \
	-lz3
SRCS	=src/cfgsolver.cxx src/Eureka.cxx src/SolverWorker.cxx src/SolverWorkerLogger.cxx \
	src/Utilities.cxx src/WorkerStatusThread.cxx src/KeepAliveThread.cxx src/WorkResponse.cxx
OBJS	=$(subst .cxx,.o,$(SRCS))
EXE	=cfgsolver.exe

all:
	@echo "No default make actions."
	@echo ""
	@echo "Important make targets to know:"
	@echo "    local:               compile locally"
	@echo "    clean:               clean locally"
	@echo "    containers:          build all containers"
	@echo "    external-containers: build non-Configurator containers"
	@echo "    worker-container:    build worker container"
	@echo "    base-container:      build supporting containers"
	@echo "    cleanup-deploy:      remove terminated Docker instances"
	@echo "    cleanup-images:      remove all local Docker containers"
	@echo "    tcsetup:             populate tc toolbox/data/lib with correct software/data"
	@echo "    tctoolbox:           populate $(TC_TOOLBOX) with correct software"

local: $(EXE)

cmake-local:
	-mkdir -p build
	cd build && cmake .. && make && mv cfgsolver ../$(EXE)

cleanup-deploy:
	-docker ps -a | awk '{print $$1}' | sed 1d | xargs docker rm

cleanup-images:
	-docker images | awk '{print $$3}' | sed 1d | xargs docker rmi -f

containers: external-containers base-containers worker-container workertest-container

external-containers:

worker-container:
	docker build . -f $(DOCKERDIR)/Dockerfile.SolverWorker.CentOS -t $(WORKERTAG)

base-containers:
	docker build . -f $(DOCKERDIR)/Dockerfile.Build.CentOS -t $(BUILDTAG)

workertest-container: worker-container
	docker build . -f $(DOCKERDIR)/Dockerfile.SolverWorkerTest.CentOS -t $(WORKERTESTTAG)

tcsetup: tctoolbox tclib tcdata

tclib:
	-if [ ! -d $(TC_LIB) ]; then mkdir $(TC_LIB); else rm -rf $(TC_LIB)/*; fi
	cp -R $(TC_CRYPTO_HOME)/bin_64/* $(TC_LIB)/
	cp -R $(TC_CURL_HOME)/libgcc48/* $(TC_LIB)/
	cp -R $(TC_CFG_SERVICE_HOME)/lib/* $(TC_LIB)/

tcdata:
	-if [ ! -d $(TC_DATA) ]; then mkdir $(TC_DATA); else rm -rf $(TC_DATA)/*; fi
	cp -R $(TC_CFG_SERVICE_HOME)/data/* $(TC_DATA)/
	cp logger.properties $(TC_DATA)/
	mkdir -p $(TC_DATA)/debug
	sed '/logging.logger.Teamcenter=WARN/c\logging.logger.Teamcenter=DEBUG' < logger.properties > $(TC_DATA)/debug/logger.properties
	# use this to turn off most of the copious debug output and speed things up a bit
	# cp logger.properties $(TC_DATA)/debug

tctoolbox:
	-mkdir -p $(TC_TOOLBOX)/$(PLATFORM)
	(cd $(TC_TOOLBOX)/$(PLATFORM); \
		rm -rf $(TC_CURL_HOME); \
		if [ -d $(TC_CURL_HOME) ]; then rm -rf $(TC_CURL_HOME); fi ; \
		wget -q "$(ARTIFACTORY)/generic-local/com/siemens/tc_toolbox/lnx64/curl/$(TC_CURL_VERSION).zip"; \
		unzip $(TC_CURL_VERSION).zip; \
		rm $(TC_CURL_VERSION).zip)
	(set -eux; cd $(TC_TOOLBOX)/$(PLATFORM); \
		if [ -d $(TC_CRYPTO_HOME) ]; then rm -rf $(TC_CRYPTO_HOME); fi ; \
		wget -q "$(ARTIFACTORY)/generic-local/com/siemens/tc_toolbox/lnx64/tccrypto/TcCrypto.$(TC_CRYPTO_VERSION).zip"; \
		unzip TcCrypto.$(TC_CRYPTO_VERSION).zip; rm TcCrypto.$(TC_CRYPTO_VERSION).zip)
	(set -eux; cd $(TC_TOOLBOX); \
		if [ -d $(TC_RAPIDJSON_HOME) ]; then rm -rf $(TC_RAPIDJSON_HOME); fi ; \
		wget -q "$(ARTIFACTORY)/generic-local/com/siemens/tc_toolbox/rapidjson/rapid_json.$(TC_RAPIDJSON_VERSION).zip"; \
		unzip rapid_json.$(TC_RAPIDJSON_VERSION).zip; rm rapid_json.$(TC_RAPIDJSON_VERSION).zip)
	(set -eux; cd $(TC_TOOLBOX)/$(PLATFORM); \
		if [ -d $(TC_CFG_SERVICE_HOME) ]; then rm -rf $(TC_CFG_SERVICE_HOME); fi ; \
		wget -q "$(ARTIFACTORY)/generic-local/com/siemens/configurator/tc/tc_configurator_$(TC_CFG_SERVICE_VERSION)_lnx64.zip"; \
		unzip tc_configurator_$(TC_CFG_SERVICE_VERSION)_lnx64.zip; \
		rm tc_configurator_$(TC_CFG_SERVICE_VERSION)_lnx64.zip; \
		cd tc_configurator/lib; \
		ln -s libicudata641_X_17.so.64 libicudata641_X_17.so; \
		ln -s libicuuc641_X_17.so.64 libicuuc641_X_17.so)
	(set -eux; \
		mkdir -p $(HAZELCAST_HOME); \
		cp hazelcast-cpp-client-$(HAZELCAST_CPPCLIENT_VERSION)-Linux_64.tgz $(HAZELCAST_HOME); \
		cd $(HAZELCAST_HOME); \
		if [ -d $(HAZELCAST_CPPCLIENT_HOME) ]; then rm -rf $(HAZELCAST_CPPCLIENT_HOME); fi; \
		tar xzf hazelcast-cpp-client-$(HAZELCAST_CPPCLIENT_VERSION)-Linux_64.tgz; \
		mv cpp $(HAZELCAST_CPPCLIENT_HOME); \
		rm hazelcast-cpp-client-$(HAZELCAST_CPPCLIENT_VERSION)-Linux_64.tgz)
	# Leave commented out for future references when we need to add some temporary files.
	#cp -r src/booleanmath $(TC_CFG_SERVICE_HOME)/include/booleanmath
	#ls $(TC_CFG_SERVICE_HOME)/include/booleanmath


$(EXE): $(OBJS)
	$(CXX) $(LDFLAGS) -o $@ $(OBJS) $(LDLIBS)

clean:
	-rm -f $(EXE) $(OBJS)

%.o: %.cxx
	$(CXX) $(CPPFLAGS) -o $@ -c $<
