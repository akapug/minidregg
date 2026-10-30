//! Signed member request used only to provision a fresh controller. It carries
//! no bearer, endpoint, filesystem path or authority to change a running task.
use super::*;
use ring::signature::{Ed25519KeyPair, KeyPair};
use sha2::{Digest, Sha256};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Choice {
    pub owner: Owner,
    pub runner: String,
    pub task: String,
    pub provider: String,
    pub model: String,
    pub table_sha256: String,
    pub signature: String,
}
impl Choice {
    pub fn body(&self) -> Value {
        json!({"type":"mini-provider-choice-v1", "owner":{"subject":self.owner.subject,"publicKey":self.owner.public_key},
            "runner":self.runner,"task":self.task,"provider":self.provider,"model":self.model,"tableSha256":self.table_sha256})
    }
    fn signing_bytes(&self) -> Vec<u8> {
        let mut out = b"mini/provider-choice/v1\0".to_vec();
        for part in [
            &self.owner.subject,
            &self.owner.public_key,
            &self.runner,
            &self.task,
            &self.provider,
            &self.model,
            &self.table_sha256,
        ] {
            out.extend_from_slice(&(part.len() as u32).to_le_bytes());
            out.extend_from_slice(part.as_bytes());
        }
        out
    }
    pub fn to_json(&self) -> Value {
        let mut value = self.body();
        value["signature"] = json!(self.signature);
        value
    }
    pub fn signed(
        owner: Owner,
        runner: &str,
        task: &str,
        provider: &str,
        model: &str,
        table: &ProviderTable,
        seed: &[u8; 32],
    ) -> Result<Self, String> {
        let choice =
            Self::signed_for_catalogue(owner, runner, task, provider, model, &table.sha256, seed)?;
        choice.validate_route(table)?;
        Ok(choice)
    }
    pub fn signed_for_catalogue(
        owner: Owner,
        runner: &str,
        task: &str,
        provider: &str,
        model: &str,
        table_sha256: &str,
        seed: &[u8; 32],
    ) -> Result<Self, String> {
        let key = Ed25519KeyPair::from_seed_unchecked(seed)
            .map_err(|_| "member signing key unavailable")?;
        if hex(key.public_key().as_ref()) != owner.public_key {
            return Err("member choice signing key differs from owner".into());
        }
        let mut choice = Self {
            owner,
            runner: runner.into(),
            task: task.into(),
            provider: provider.into(),
            model: model.into(),
            table_sha256: table_sha256.into(),
            signature: String::new(),
        };
        choice.signature = hex(key.sign(&choice.signing_bytes()).as_ref());
        Self::from_json(&choice.to_json())
    }
    pub fn from_json(value: &Value) -> Result<Self, String> {
        object_keys(
            value,
            &[
                "type",
                "owner",
                "runner",
                "task",
                "provider",
                "model",
                "tableSha256",
                "signature",
            ],
            "provider choice",
        )?;
        if value["type"] != "mini-provider-choice-v1" {
            return Err("unknown provider choice version".into());
        }
        let owner = value.get("owner").ok_or("provider choice owner absent")?;
        object_keys(owner, &["subject", "publicKey"], "provider choice owner")?;
        let choice = Self {
            owner: Owner::new(
                string(owner, "subject", "choice owner")?,
                string(owner, "publicKey", "choice owner")?,
            )?,
            runner: string(value, "runner", "choice")?.into(),
            task: string(value, "task", "choice")?.into(),
            provider: string(value, "provider", "choice")?.into(),
            model: string(value, "model", "choice")?.into(),
            table_sha256: string(value, "tableSha256", "choice")?.into(),
            signature: string(value, "signature", "choice")?.into(),
        };
        decimal(&choice.runner, "choice runner")?;
        decimal(&choice.task, "choice task")?;
        provider_name(&choice.provider)?;
        if choice.model.is_empty()
            || choice.model.len() > 256
            || choice.model.chars().any(char::is_control)
        {
            return Err("invalid choice model".into());
        }
        if choice.table_sha256.len() != 64 || choice.signature.len() != 128 {
            return Err("invalid choice digest or signature width".into());
        }
        // ring's Ed25519 verify accepts a small-order public key: with the identity point as key,
        // R = identity and S = 0 approve every message. The owner key is parsed again here so a weak key is
        // refused by name and the check is verify_strict (which also refuses a small-order R).
        let owner_key: [u8; 32] = unhex(&choice.owner.public_key)?
            .try_into()
            .map_err(|_| "provider choice owner key width")?;
        let owner_key = ed25519_dalek::VerifyingKey::from_bytes(&owner_key)
            .map_err(|_| "provider choice owner key is not a curve point")?;
        if owner_key.is_weak() {
            return Err("weak provider choice owner key".into());
        }
        let signature: [u8; 64] = unhex(&choice.signature)?
            .try_into()
            .map_err(|_| "provider choice signature width")?;
        owner_key
            .verify_strict(&choice.signing_bytes(), &ed25519_dalek::Signature::from_bytes(&signature))
            .map_err(|_| "provider choice signature refused")?;
        Ok(choice)
    }
    pub fn validate_route(&self, table: &ProviderTable) -> Result<(), String> {
        decimal(&self.runner, "choice runner")?;
        decimal(&self.task, "choice task")?;
        if self.table_sha256 != table.sha256 {
            return Err("provider catalogue changed; choose the route again".into());
        }
        if table.select(&self.model, Some(&self.provider))?.credential != CredentialSource::User {
            return Err("member BYOK choice needs a user credential route".into());
        }
        Ok(())
    }
    pub fn digest(&self) -> String {
        hex(&Sha256::digest(
            serde_json::to_vec(&self.to_json()).expect("choice JSON"),
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn hexs(bytes: &[u8]) -> String {
        bytes.iter().map(|b| format!("{b:02x}")).collect()
    }

    /// The identity point as the owner key with R = identity, S = 0 signs every choice without a secret.
    #[test]
    fn weak_owner_key_forgery_is_refused_by_name() {
        let mut identity = [0u8; 32];
        identity[0] = 1;
        let mut forged = [0u8; 64];
        forged[0] = 1;
        let value = json!({
            "type":"mini-provider-choice-v1",
            "owner":{"subject":"20","publicKey":hexs(&identity)},
            "runner":"21","task":"22","provider":"openrouter","model":"some-model",
            "tableSha256":"a".repeat(64),
            "signature":hexs(&forged),
        });
        let error = Choice::from_json(&value).expect_err("a forged choice under a weak owner key must not verify");
        assert!(error.contains("weak provider choice owner key"), "{error}");
    }
}
