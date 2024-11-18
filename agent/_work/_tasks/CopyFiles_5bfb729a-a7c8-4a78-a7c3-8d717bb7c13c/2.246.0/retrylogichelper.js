"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RetryHelper = void 0;
class RetryHelper {
    constructor(retryOptions) {
        this.retryOptions = retryOptions;
    }
    RunWithRetry(action, actionName) {
        return __awaiter(this, void 0, void 0, function* () {
            let attempts = this.retryOptions.numberOfReties;
            while (true) {
                try {
                    const result = yield action();
                    return result;
                }
                catch (err) {
                    --attempts;
                    if (attempts <= 0) {
                        throw err;
                    }
                    console.log(`Error while ${actionName}: ${err}. Remaining attempts: ${attempts}`);
                    yield this.sleep();
                }
            }
        });
    }
    sleep() {
        return __awaiter(this, void 0, void 0, function* () {
            return new Promise(resolve => setTimeout(resolve, this.retryOptions.timeoutBetweenRetries));
        });
    }
}
exports.RetryHelper = RetryHelper;
