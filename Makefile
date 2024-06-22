

UNITTEST_DIR       ?= test
TEST_IMAGE_TAG ?=pytest:v1.0

all: ;

build-test-image: all
	cd test && docker build -t $(TEST_IMAGE_TAG) .

build-test-env-image: all
	cd docker && docker-compose build

build: build-test-image build-test-env-image

run-test-env: all
	#启动测试环境
	cd docker && docker-compose up -d

test: all run-test-env
	#启动测试
	docker run --network host -v ./test/:/src --rm $(TEST_IMAGE_TAG) bash -c "pytest -v -p pytest_asyncio test.py"

