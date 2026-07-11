#!/usr/bin/env node
// validate-config.mjs - Validate launcher JSON configs against their schemas.
// Usage: node validate-config.mjs <configPath> <schemaPath>
// Exit 0 = valid, non-zero = invalid (errors printed to stderr).
// Minimal validator: checks required fields, type, const, enum, minLength, minItems,
// minProperties, uniqueItems, additionalProperties (basic). Not a full JSON Schema
// implementation — for full validation install ajv-cli.

import { readFileSync } from 'node:fs';
import { exit } from 'node:process';

const errors = [];

function validate(value, schema, path = '') {
  if (schema.type) {
    const expected = schema.type;
    let actual;
    if (value === null) actual = 'null';
    else if (Array.isArray(value)) actual = 'array';
    else if (typeof value === 'number' && Number.isInteger(value)) actual = 'integer';
    else actual = typeof value;
    if (expected === 'integer' && actual !== 'integer') {
      errors.push(`${path}: expected integer, got ${actual}`);
      return;
    }
    if (expected === 'string' && actual !== 'string') {
      errors.push(`${path}: expected string, got ${actual}`);
      return;
    }
    if (expected === 'boolean' && actual !== 'boolean') {
      errors.push(`${path}: expected boolean, got ${actual}`);
      return;
    }
    if (expected === 'object' && actual !== 'object') {
      errors.push(`${path}: expected object, got ${actual}`);
      return;
    }
    if (expected === 'array' && actual !== 'array') {
      errors.push(`${path}: expected array, got ${actual}`);
      return;
    }
  }
  if (schema.const !== undefined && value !== schema.const) {
    errors.push(`${path}: expected const ${JSON.stringify(schema.const)}, got ${JSON.stringify(value)}`);
  }
  if (schema.enum && !schema.enum.includes(value)) {
    errors.push(`${path}: value ${JSON.stringify(value)} not in enum [${schema.enum.join(', ')}]`);
  }
  if (schema.minLength !== undefined && typeof value === 'string' && value.length < schema.minLength) {
    errors.push(`${path}: string length ${value.length} < minLength ${schema.minLength}`);
  }
  if (schema.minItems !== undefined && Array.isArray(value) && value.length < schema.minItems) {
    errors.push(`${path}: array length ${value.length} < minItems ${schema.minItems}`);
  }
  if (schema.minProperties !== undefined && typeof value === 'object' && !Array.isArray(value) && Object.keys(value).length < schema.minProperties) {
    errors.push(`${path}: object props ${Object.keys(value).length} < minProperties ${schema.minProperties}`);
  }
  if (schema.uniqueItems && Array.isArray(value)) {
    const seen = new Set();
    for (const item of value) {
      const key = JSON.stringify(item);
      if (seen.has(key)) {
        errors.push(`${path}: duplicate item ${key} (uniqueItems violated)`);
      }
      seen.add(key);
    }
  }
  // required
  if (schema.required && typeof value === 'object' && !Array.isArray(value)) {
    for (const req of schema.required) {
      if (!(req in value)) {
        errors.push(`${path}: missing required field '${req}'`);
      }
    }
  }
  // properties
  if (schema.properties && typeof value === 'object' && !Array.isArray(value)) {
    for (const [key, subSchema] of Object.entries(schema.properties)) {
      if (key in value) {
        validate(value[key], subSchema, path ? `${path}.${key}` : key);
      }
    }
  }
  // additionalProperties (only when false and properties is defined)
  if (schema.additionalProperties === false && schema.properties && typeof value === 'object' && !Array.isArray(value)) {
    for (const key of Object.keys(value)) {
      if (!(key in schema.properties)) {
        errors.push(`${path}: additional property '${key}' not allowed`);
      }
    }
  }
  // array items
  if (schema.items && Array.isArray(value)) {
    for (let i = 0; i < value.length; i++) {
      validate(value[i], schema.items, `${path}[${i}]`);
    }
  }
}

function main() {
  const [configPath, schemaPath] = process.argv.slice(2);
  if (!configPath || !schemaPath) {
    console.error('Usage: node validate-config.mjs <configPath> <schemaPath>');
    exit(2);
  }
  let config, schema;
  try {
    config = JSON.parse(readFileSync(configPath, 'utf-8'));
  } catch (e) {
    console.error(`Failed to parse config ${configPath}: ${e.message}`);
    exit(1);
  }
  try {
    schema = JSON.parse(readFileSync(schemaPath, 'utf-8'));
  } catch (e) {
    console.error(`Failed to parse schema ${schemaPath}: ${e.message}`);
    exit(1);
  }
  validate(config, schema);
  if (errors.length > 0) {
    console.error(`INVALID: ${configPath} (${errors.length} errors)`);
    for (const e of errors) {
      console.error(`  - ${e}`);
    }
    exit(1);
  }
  console.log(`VALID: ${configPath}`);
  exit(0);
}

main();
